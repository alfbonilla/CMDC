class CmNc < ActiveRecord::Base
  include CmDocCountersHelper
  
  belongs_to :project
  belongs_to :type, :class_name => 'CmNcsType', :foreign_key => 'type_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :company, :class_name => 'CmCompany', :foreign_key => 'company_id'
  belongs_to :status, :class_name => 'CmNcsStatus', :foreign_key => 'status_id'
  belongs_to :classification, :class_name => 'CmNcsClassification', :foreign_key => 'classification_id'
  belongs_to :phase, :class_name => 'CmNcsPhase', :foreign_key => 'phase_id'
  belongs_to :rlse_detected, :class_name => 'Version', :foreign_key => 'rlse_detected_id'
  belongs_to :rlse_solved, :class_name => 'Version', :foreign_key => 'rlse_solved_id'
  belongs_to :rlse_verified, :class_name => 'Version', :foreign_key => 'rlse_verified_id'
  belongs_to :rlse_expected, :class_name => 'Version', :foreign_key => 'rlse_expected_id'
  belongs_to :supplier, :class_name => 'CmCompany', :foreign_key => 'supplier_id'
  belongs_to :qr, :class_name => 'CmQr', :foreign_key => 'cm_qr_id'
  belongs_to :subsystem, :class_name => 'CmSubsystem', :foreign_key => 'subsystem_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_ncs_objects, :dependent => :destroy
  has_many :items, :through => :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmItem'"
  has_many :cm_ncs_ncs, :class_name => 'CmNcsNc', :foreign_key => 'cm_nc_id', :dependent => :delete_all
  has_many :cm_ncs_parent_ncs, :class_name => 'CmNcsNc', :foreign_key => 'child_nc_id', :dependent => :delete_all
  has_many :cm_smrs
  has_many :cm_was
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmNc'", :dependent => :destroy
  has_many :reqs, :through => :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'"
  has_many :docs, :through => :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmDoc'"
  has_many :test_records, :through => :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmTestRecord'"

  before_destroy :check_integrity

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable

  attr_reader :current_journal
  attr_accessor :counter_type

  named_scope :no_qr_related,  :conditions => ["cm_qr_id = 0"]
  named_scope :open, :conditions => ["#{CmNcsStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :closed, :conditions => ["#{CmNcsStatus.table_name}.is_closed = ?", true], :include => :status
  named_scope :my_project, lambda { |project| {:conditions => ["#{CmNc.table_name}.project_id=?", project]}}
  named_scope :my_ncs, lambda { |user| {:conditions => ["#{CmNc.table_name}.assigned_to_id=?", user]}}
  named_scope :ready_to_verify, :conditions => ["#{CmNcsStatus.table_name}.is_ready_to_verify = ?", true],
    :include => :status
  
  NC_PRIORITIES = %w(high medium low)

  validates_presence_of :code, :name, :rlse_detected_id, :assigned_to_id
  validates_inclusion_of :priority, :in => NC_PRIORITIES
  #validate :review_naming_standards
  validate :closed_statuses_management
  validates_uniqueness_of :code, :scope => :project_id
  
  after_save :create_journal

  # Users the NC can be assigned to
  def assignable_users
    project.assignable_users
  end 

  def after_initialize
    if new_record?
      # set default values for new records only
      if new_record?
        unless project.nil?
          self.type ||= CmNcsType.default(project)
          self.status ||= CmNcsStatus.default(project)
          self.phase ||= CmNcsPhase.default(project)
          self.classification ||= CmNcsClassification.default(project)
        end
      end
    end
  end

  # Return true if the nc is closed, otherwise false
  def closed?
    self.status.is_closed?
  end

  def ready_to_verify?
    self.status.is_ready_to_verify
  end

  def has_was?
    if self.cm_was.any?
      true
    else
      false
    end
  end

  # Management for the closing of a NC or the re-open !!
  
  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def before_save
    self.supplier_id=0 if self.supplier_id.nil?
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmNcJournal.new(:journalized => self, :user => user, :notes => notes)
    @nc_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmNc.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @nc_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@nc_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

#  def review_naming_standards
#    # get pattern from cm_nc_types table and match against the introduced code!
#    if self.child_nc_id == self.cm_nc_id
#      errors.add(:child_nc_id, "can't be the same than origin")
#    end
#  end


  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_ncs, self.project)
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = project.notified_users
    # Author and assignee are always notified unless they have been locked
    notified << author if author && author.active?
    notified << assignee if assignee && assignee.active?
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified.collect(&:mail)
  end

  def to_s; name end

  private
  def check_integrity
    if CmDeliveriesObject.find(:first, :conditions => ["x_id=? and (x_type=? or x_type=?)",
          self.id, "CmNc", "CmNcClosed"])
      raise "Can't delete doc because is included in delivery!!"
    end
  end

  def closed_statuses_management
    new_status = CmNcsStatus.find(@attributes['status_id'])

    if new_record? and new_status.is_closed
        self.closing_date = Time.now
    end

    #If the nc passes from some non closed status to a closed one
    if new_status.is_closed and self.status.is_opened
        self.closing_date = Time.now
    end

    #If the nc passes from some closed status to a non closed one
    if self.status.is_closed and new_status.is_opened
      self.closing_date = nil
    end
  end

  def validate_on_create  #unique_code
    #Get code again from Code Generator
    cm_ncs_type = CmNcsType.find(self.type_id)
    @cm_subsystem = CmSubsystem.find(self.subsystem_id) unless self.subsystem_id.blank?

    if cm_ncs_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_ncs_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end

      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.code, @cm_doc_counter.format, new_value,
                cm_ncs_type.acronym, @cm_subsystem)
        rescue RuntimeError => e
          errors.add(:code, e.message)
          return
        end
        #At this point, the oldcode was correctly formed, but it could be different
        #because counter points to different code
        code_in_table=CmNc.find_by_code(self.code)
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
    end
  end
end
