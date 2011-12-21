class CmReq < ActiveRecord::Base
  #Functionality for backingup the stable version
  #. before_save method => if edit, status=stable and the change affects to one of
  #                        the x columns => create copy and change status to proposed

  include CmDocCountersHelper
  
  belongs_to :project
  belongs_to :type, :class_name => 'CmReqsType', :foreign_key => 'type_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :classification, :class_name => 'CmReqsClassification', :foreign_key => 'classification_id'
  belongs_to :subsystem, :class_name => 'CmSubsystem', :foreign_key => 'subsystem_id'
  belongs_to :verification_method, :class_name => 'CmTestVerificationMethod', :foreign_key => 'verification_method_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
#  has_many :cm_reqs_reqs, :dependent => :destroy

  has_many :cm_reqs_reqs, :class_name => 'CmReqsReq', :foreign_key => 'cm_req_id', :dependent => :delete_all
  has_many :cm_reqs_parent_reqs, :class_name => 'CmReqsReq', :foreign_key => 'child_req_id', :dependent => :delete_all
  
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmReq'", :dependent => :destroy
  has_many :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'",
              :dependent => :destroy
  has_many :cm_changes_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'",
              :dependent => :destroy
  has_many :cm_rids_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'",
              :dependent => :destroy
  has_many :cm_tests_objects, :class_name => 'CmTestsObject',:foreign_key => 'x_id', :conditions => "x_type = 'CmReq'",
              :dependent => :destroy

  before_destroy :check_integrity

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable

  attr_reader :current_journal
  attr_accessor :counter_type

  # 3 statuses => Dismissed = 3, Proposed = 2 and Stable = 1
  # Req is considered open when it is in status Proposed (same than changed)
  named_scope :changed, :conditions => ["#{CmReq.table_name}.status = ?", 2]
  named_scope :my_project, lambda { |project| {:conditions => ["#{CmReq.table_name}.project_id=?", project]}}
  named_scope :my_reqs, lambda { |user| {:conditions => ["#{CmReq.table_name}.assigned_to_id=?", user]}}
  
  validates_presence_of :code, :name
  validates_uniqueness_of :code, :scope => :project_id
  
  after_save :create_journal

  # Users the Req can be assigned to
  def assignable_users
    project.assignable_users
  end 

  def after_initialize
    if new_record?
      # set default values for new records only
      unless project.nil?
        self.type ||= CmReqsType.default(project)
        self.classification ||= CmReqsClassification.default(project)
      end
    end
  end

  # Return true if the Req is closed, otherwise false
  def changed?   
    true if self.status == 2
  end

  def soc_control_required?
    true if self.type.soc_control
  end

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  # By default, status set to Proposed
  def before_save
    self.status=2 if self.status.nil?

    #This control avoids that attributes were validated coming from "internal" updates
    if not @Req_before_change.nil? and @Req_save
      save_tempo_record=false
      temp_rel_record=CmTempoReqsReq.find(:first,
          :conditions => ["cm_req_id=?", self.id])

      # This process is performed if status was STABLE or there is some temp relation
      if @Req_before_change.status == 1 or temp_rel_record
        (CmReq.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
          unless send(c)==@Req_before_change.send(c)
            # Analyze modified column to see if there is necessary to create a backup or not
            # Auditory are not included in loop; status can not be changed
            if c!="assigned_to_id" and c!="comments" and c!="display_order" and
              c!="place_in_doc" and c!="assumption" and c!="compliance"
              save_tempo_record=true
            end
          end
        }
      end
      if save_tempo_record
        # Not necessary searching for existing record in DB: it can not be!
        #unless CmTempoReq.find(:first, :conditions => ["req_id = ?", self.id])
        if self.status == 3
          action="DISMISS"
        else
          action="EDIT"
        end
        CmTempoReq.create(:req_id => self.id,
          :code => @Req_before_change.send('code'),
          :name => @Req_before_change.send('name'),
          :description => @Req_before_change.send("description"),
          :version => @Req_before_change.send("version"),
          :type_id => @Req_before_change.send("type_id"),
          :classification_id => @Req_before_change.send("classification_id"),
          :subsystem_id => @Req_before_change.send("subsystem_id"),
          :verification_method_id => @Req_before_change.send("verification_method_id"),
          :no_ascendants => @Req_before_change.send("no_ascendants"),
          :no_descendants => @Req_before_change.send("no_descendants"),
          :optional => @Req_before_change.send("optional"),
          :status => @Req_before_change.send("status"),
          :assigned_to_id => @Req_before_change.send("assigned_to_id"),
          :display_order => @Req_before_change.send("display_order"),
          :place_in_doc => @Req_before_change.send("place_in_doc"),
          :project_id => @Req_before_change.send("project_id"),
          :author_id => @Req_before_change.send("author_id"),
          :created_on => @Req_before_change.send("created_on"),
          :updated_on => @Req_before_change.send("updated_on"),
          :action => action)

        #Change status to proposed
        self.status=2

        self.errors.add_to_base("Traceability Element status set as Proposed")
        #end
      end
    end
  end

  def init_journal(user, notes = "")
    #Control for not saving when not desired
    if notes=="CM/DC-NotSave"
      @Req_save=false
      notes=""
    else
      @Req_save=true
    end

    @current_journal ||= CmReqJournal.new(:journalized => self, :user => user, :notes => notes)
    @Req_before_change = self.clone

    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmReq.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
          @current_journal.details << JournalDetail.new(:property => 'attr',
                                                :prop_key => c,
                                                :old_value => @Req_before_change.send(c),
                                                :value => send(c)) unless send(c)==@Req_before_change.send(c)
      }
      @current_journal.save
    end
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  # Returns true if usr or current user is allowed to view the req
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_reqs, self.project)
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
          self.id, "CmReq", "CmReqClosed"])
      raise "Can't delete Traceability Element because is included in delivery!!"
    end
  end

  def validate_on_create  #unique_code
    #Get code again from Code Generator
    cm_reqs_type = CmReqsType.find(self.type_id)
    @cm_subsystem = CmSubsystem.find(self.subsystem_id) unless self.subsystem_id.blank?
    if cm_reqs_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_reqs_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end

      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.code, @cm_doc_counter.format, new_value,
                    cm_reqs_type.acronym, @cm_subsystem, self.version)
        rescue RuntimeError => e
          errors.add(:code, e.message)
          return
        end

        #At this point, the oldcode was correctly formed, but it could be different
        #because counter points to different code
        code_in_table=CmReq.find_by_code(self.code)
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
