class CmChange < ActiveRecord::Base
  include CmDocCountersHelper

  belongs_to :project
  belongs_to :status, :class_name => 'CmChangeStatus', :foreign_key => 'status_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :type, :class_name => 'CmChangeType', :foreign_key => 'type_id'
  belongs_to :source_company, :class_name => 'CmCompany', :foreign_key => 'from_company'
  belongs_to :target_company, :class_name => 'CmCompany', :foreign_key => 'to_company'
  belongs_to :change_doc, :class_name => 'CmDoc', :foreign_key => 'cm_doc_id'
  belongs_to :affected_doc, :class_name => 'CmDoc', :foreign_key => 'affected_doc_id'
  belongs_to :affected_item, :class_name => 'CmItem', :foreign_key => 'affected_item_id'
  belongs_to :release, :class_name => 'Version', :foreign_key => 'release_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_changes_versions, :dependent => :destroy
  has_many :cm_changes_objects, :dependent => :destroy
  has_many :cm_child_changes, :class_name => 'CmChangesChange', :foreign_key => 'parent_change_id'
  has_many :cm_parent_changes, :class_name => 'CmChangesChange', :foreign_key => 'child_change_id', :dependent => :destroy
  has_many :cm_smrs
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmChange'", :dependent => :destroy
  has_many :reqs, :through => :cm_changes_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'"

  before_destroy :check_integrity

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable
  
  attr_reader :current_journal
  attr_accessor :counter_type  

  named_scope :open, :conditions => ["#{CmChangeStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :my_project, lambda { |project| {:conditions => ["#{CmChange.table_name}.project_id=?", project]}}

  validates_presence_of :status, :type, :code, :name
  validates_length_of :code, :maximum =>30
  validates_length_of :name, :maximum =>100
  validates_uniqueness_of :code, :scope => :project_id
  
  after_save :create_journal
  
  def after_initialize
    if new_record?
      unless project.nil?
        self.type ||= CmChangeType.default(project)
        self.status ||= CmChangeStatus.default(project)
      end
    end
  end  
    
  def closed?
    self.status.is_closed?
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  # Returns an array of status that user is able to apply
  def new_statuses_allowed_to(user)
    statuses = status.find_new_statuses_allowed_to(user.roles_for_project(project), @cm_change_tracker)
    statuses << status unless statuses.empty?
    statuses = statuses.uniq.sort
    blocked? ? statuses.reject {|s| s.is_closed?} : statuses
  end  

  #
  # Journal Functionality Implementation
  #
  def after_save
    # Reload is needed in order to get the right status
    reload
  end
  
  def init_journal(user, notes = "")
    @current_journal ||= ChangeJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_change_before_change = self.clone
    @cm_change_before_change.status = self.status
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end
  
  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmChange.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_change_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_change_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_changes, self.project)
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = project.notified_users
    # Author and assignee are always notified unless they have been locked
    notified << author if author && author.active?
    #notified << assigned_to if assigned_to && assigned_to.active?
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified.collect(&:mail)
  end
  
  def to_s
    "#{CmChange} ##{id}: #{Name}"
  end   

  private
  def check_integrity
    if CmDeliveriesObject.find(:first, :conditions => ["x_id=? and x_type=?",
          self.id, "CmChange"])
      raise "Can't delete change because is included in delivery!!"
    end
    if CmChangesObject.find(:first, :conditions => ["x_id=? and x_type=?",
          self.id, "CmChange"])
      raise "Can't delete change because is included in board!!"
    end
  end

  def validate_on_create  #unique_code
    #Get code again from Code Generator
    cm_change_type = CmChangeType.find(self.type_id)
    if cm_change_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_change_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end

      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.code, @cm_doc_counter.format, new_value,
                cm_change_type.acronym)
        rescue RuntimeError => e
          errors.add(:code, e.message)
          return
        end
        #At this point, the oldcode was correctly formed, but it could be different
        #because counter points to different code
        code_in_table=CmChange.find_by_code(self.code)
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
