class CmRid < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper

  belongs_to :project
  belongs_to :close_out, :class_name => 'CmRidCloseOut', :foreign_key => 'close_out_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :open_release, :class_name => 'Version', :foreign_key => 'open_release_id'
  belongs_to :originator_company, :class_name => 'CmCompany', :foreign_key => 'originator_company_id'
  belongs_to :affected_doc, :class_name => 'CmDoc', :foreign_key => 'affected_doc_id'
  belongs_to :implementation_release, :class_name => 'Version', :foreign_key => 'implementation_release_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_rids_objects, :dependent => :destroy
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmRid'", :dependent => :destroy
  has_many :reqs, :through => :cm_rids_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'"
  
  before_destroy :check_integrity

  acts_as_watchable
  acts_as_attachable :after_remove => :attachment_removed

  attr_reader :current_journal

  attr_accessor :board_to_relate

  #Value set in helper as Closed
  named_scope :open, 
    :conditions => ["#{CmRid.table_name}.internal_status_id != ? and #{CmRid.table_name}.internal_status_id != ? ", 2, 3]
  named_scope :my_project, lambda { |project| {:conditions => ["#{CmRid.table_name}.project_id=?", project]}}
  named_scope :my_rids, lambda { |user| {:conditions => ["#{CmRid.table_name}.assigned_to_id=?", user]}}

  validates_presence_of :code
  validate :status_close_out
  validates_uniqueness_of :code, :scope => :project_id
  
  after_save :create_journal
  
  def after_initialize
    if new_record?
      unless project.nil?
        self.close_out ||= CmRidCloseOut.default(self.project_id)
      end
    end
  end  

  # Users the RID can be assigned to
  def assignable_users
    project.assignable_users
  end

  def closed?
    self.close_out.is_closed?
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  #
  # Journal Functionality Implementation
  #
  def after_save
    # Reload is needed in order to get the right status
    reload
  end
  
  def init_journal(user, notes = "")
    @current_journal ||= RidJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_rid_before_rid = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end
  
  # Saves the Rids in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      # attributes Rids: all columns except the ones included in the sentence
      (CmRid.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_rid_before_rid.send(c),
                                                      :value => send(c)) unless send(c)==@cm_rid_before_rid.send(c)
      }     
      @current_journal.save
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_rids, self.project)
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
  
  def to_s
    "#{CmRid} ##{id}"
  end   

  private
  def check_integrity
    if CmDeliveriesObject.find(:first, :conditions => ["x_id=? and x_type=?",
          self.id, "CmRid"])
      raise "Can't delete Rid because is included in delivery!!"
    end
  end

  def status_close_out
    #If status is not closed, close_out has to be open
    #2=>Closed (helper)
    new_close_out = CmRidCloseOut.find(self.close_out_id)

    if new_close_out.is_closed? and (self.internal_status_id != 2 and self.internal_status_id != 3)
      errors.add(:internal_status_id, "has to be Closed or Withdrawn, if Close Out value is close considered")
    end

    if not new_close_out.is_closed? and (self.internal_status_id == 2 or self.internal_status_id == 3)
      errors.add(:internal_status_id, "can not be Closed or Withdrawn, if Close Out value is not close considered")
    end
  end

  def validate_on_create    #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Rid'), @project.id])
    unless @cm_doc_counter.blank?
      new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
      begin
        new_code=get_new_code(self.code, @cm_doc_counter.format, new_value)
      rescue RuntimeError => e
        errors.add(:code, e.message)
        return
      end
      #At this point, the oldcode was correctly formed, but it could be different
      #because counter points to different code
      code_in_table=CmRid.find_by_code(self.code)
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
