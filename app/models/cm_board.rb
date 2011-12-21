class CmBoard < ActiveRecord::Base
  include CmDocCountersHelper

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :company, :class_name => 'CmCompany', :foreign_key => 'company_id'
  belongs_to :type, :class_name => 'CmBoardType', :foreign_key => 'type_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_ncs_objects, :foreign_key => 'x_id',
            :conditions => "x_type = 'CmBoard'", :dependent => :destroy
  has_many :cm_changes_objects, :foreign_key => 'x_id',
            :conditions => "x_type = 'CmBoard'", :dependent => :destroy
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
            :conditions => "cm_object_type = 'CmBoard'", :dependent => :destroy
  has_many :cm_rids_objects, :foreign_key => 'x_id',
            :conditions => "x_type = 'CmBoard'", :dependent => :destroy

  acts_as_watchable
  acts_as_attachable :after_remove => :attachment_removed

  attr_reader :current_journal
  
  validates_presence_of :cm_board_code, :meeting_date, :subject
  validate :minutes_editable
  validates_uniqueness_of :cm_board_code, :scope => :project_id

  after_save :create_journal
  attr_accessor :counter_type

  def after_initialize
    if new_record?
      unless project.nil?
        self.type ||= CmBoardType.default(project)
      end
    end
  end

  # Journal Functionality Implementation
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmBoardJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_board_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmBoard.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_board_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_board_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_boards, self.project)
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

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  # Users the cm_board can be assigned to
  def assignable_users
    project.assignable_users
  end
  
  def to_s; name end  

  private

  def minutes_editable
   
    #this code (*@*) is sent by controller from reopen action
    unless self.participants[0,3] == '*@*'
      if minutes_closed_was
        errors.add(:minutes_closed, "specifies that the board is closed. To reopen, use contextual menu action.")
      end
    else
      self.participants = self.participants[3, self.participants.length - 3]
    end
  end

  def validate_on_create #unique_code
    #Get code again from Code Generator
    cm_board_type = CmBoardType.find(self.type_id)
    if cm_board_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_board_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end
      
      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.cm_board_code, @cm_doc_counter.format, 
            new_value, cm_board_type.acronym)
        rescue RuntimeError => e
          errors.add(:cm_board_code, e.message)
          return
        end
        code_in_table=CmBoard.find_by_cm_board_code(self.cm_board_code)
        if code_in_table.nil?
          # code not taken. Continue with received value and update counter
          if self.cm_board_code == new_code
            # Update code counter
            CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
          end
        else
          # code already taken
          if self.cm_board_code != new_code
            # Code already exists, advise user of code changing
            self.cm_board_code = new_code
          end
          # Update code counter anyway for next code generation
          CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
        end
      end
    end
  end

end