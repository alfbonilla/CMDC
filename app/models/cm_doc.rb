class CmDoc < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :type, :class_name => 'CmDocType', :foreign_key => 'type_id'
  belongs_to :company, :class_name => 'CmCompany', :foreign_key => 'originator_company_id'
  belongs_to :category, :class_name => "DocumentCategory", :foreign_key => 'category_id'
  belongs_to :subsystem, :class_name => 'CmSubsystem', :foreign_key => 'subsystem_id'

  has_many :rids, :class_name => 'CmRid', :foreign_key => 'affected_doc_id'
  has_many :cm_docs_versions, :dependent => :destroy
  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmDoc'", :dependent => :destroy
  has_many :cm_items_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmDoc'", :dependent => :destroy
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id', 
              :conditions => "cm_object_type = 'CmDoc'", :dependent => :destroy
  #has_many :issues, :through => :cm_objects_issues, :foreign_key => 'issue_id'

  before_destroy :check_integrity
  after_save :create_journal

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable

  attr_reader :current_journal
  attr_accessor :counter_type

  # These 5 accessors are used in new_record for creating the first version of the document
  attr_accessor :l_version
  attr_accessor :l_physical_location
  attr_accessor :l_applicable
  attr_accessor :l_assigned_to_id
  attr_accessor :l_status_id
 
  validates_presence_of :code, :name
  validates_uniqueness_of :code, :scope => :project_id
  
  def after_initialize
    #Rails error when model fails (eg: validate_uniqueness... Solved in 2.3.6)
    if new_record?
      self.type ||= CmDocType.default(project) unless project.nil?
      self.l_status_id ||= CmDocStatus.default(project) unless project.nil?
    end
  end

  # Users the doc can be assigned to
  def assignable_users
    project.assignable_users
  end

  def applicable?
    app=false
    self.cm_docs_versions.each do |ver|
      if ver.applicable
        app=true
        break
      end
    end
    app
  end

  # Last Version associated to the doc
  def last_version
    max=0
    last_ver=CmDocsVersion.new
    self.cm_docs_versions.each do |ver|
      if ver.id > max
        max = ver.id
        last_ver=ver
      end
    end
    last_ver
  end

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmdocJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_doc_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmDoc.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_doc_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_doc_before_change.send(c)
      }
      @current_journal.save
    end
    #New docs require to create the first version
    create_first_version() if @create_first_version
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "Attachment " + obj.filename + " deleted!"
    journal.save
  end

  def to_s; name end

  private

  def check_integrity
    dl=CmDeliveriesObject.find(:first, :conditions => ["x_id=? and x_type=?",
          self.id, "CmDoc"])
    raise "Can't delete doc because was delivered in " + dl.delivery.code if dl

    ch=CmChange.find(:first, :conditions => ["cm_doc_id=?", self.id])
    raise "Can't delete doc because is related to Change " + ch.code if ch
    
    to=CmTestsObject.find(:first, :conditions => ["x_id=? and x_type=?",
          self.id, "CmDoc"])
    raise "Can't delete doc because is used by Test " + to.cm_test.code if to
  end

  def validate_on_create  #unique_code
    #Version has to be completed
    @create_first_version=false
    errors.add(:l_version, "can't be blank") if self.l_version.empty?

    #Get code again from Code Generator
    cm_doc_type = CmDocType.find(self.type_id)
    @cm_subsystem = CmSubsystem.find(self.subsystem_id) unless self.subsystem_id.blank?

    if cm_doc_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_doc_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end

      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.code, @cm_doc_counter.format, new_value,
            cm_doc_type.acronym, @cm_subsystem, self.l_version, self.approval_level)
        rescue RuntimeError => e
          errors.add(:code, e.message)
          return
        end

        #At this point, the oldcode was correctly formed, but it could be different
        #because counter points to different code
        code_in_table=CmDoc.find_by_code(self.code)
        if code_in_table.nil?
          # code not taken. Continue with received value and update counter
          if self.code == new_code
            # Update code counter
            CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
          end
        else
          # code already taken
          if self.code != new_code
            # Code already exists, advise user of code changing
            self.code = new_code
          end
          # Update code counter anyway for next code generation
          CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
        end
      end
      @create_first_version=true
    end
  end

#  ** Commented when moving attributes (including version) to other table
#  ** Attributes directly related to the version could be modified before (this method)
#  ** If user changes the code, the type... it's up to the user
#  def validate_on_update  #new_issue
#    # This method just has to be executed when columns different from here controlled are modified
#    # If coming from doc_versions for updating the applicable field value, this validation is skipped too
#    validate=false
#    if @cm_doc_before_change
#      (CmDoc.column_names - %w(id description status_id updated_on assigned_to_id deliverable referable baseline)).each {|c|
#        if send(c)!= @cm_doc_before_change.send(c)
#          validate=true
#          break
#        end
#      }
#    end
#
#    if validate
#      deliv_docs = CmDeliveriesObject.find(:all, :conditions => ["x_id=? and x_type=?",
#            self.id, "CmDoc"])
#      deliv_docs.each do |dd|
#        # Document already delivered. Review issue number
#        if dd.rel_string == self.l_version
#          errors.add(:l_version, "this issue has been already delivered. Change it before continue!")
#        end
#      end
#    end
#  end

  def create_first_version()
    cm_docs_version=CmDocsVersion.create({:version => self.l_version,
    :physical_location => self.l_physical_location,
    :cm_doc_id => self.id, :applicable => self.l_applicable, :comments => "",
    :status_id => self.l_status_id, :assigned_to_id => self.l_assigned_to_id,
    :author => User.current})

    #Deliver mail
    Mailer.deliver_cmdc_info(User.current, self.project, cm_docs_version, 'cm_docs_versions')
  end

end