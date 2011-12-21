class CmMntLog < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :installer, :class_name => 'User', :foreign_key => 'maintained_by_id'
  belongs_to :type, :class_name => 'CmMntLogType', :foreign_key => 'type_id'
  belongs_to :status, :class_name => 'CmMntLogStatus', :foreign_key => 'status_id'
  belongs_to :item, :class_name => 'CmItem', :foreign_key => 'cm_item_id'
  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmMntLog'", :dependent => :destroy

  acts_as_attachable :after_remove => :attachment_removed

  attr_reader :current_journal

  named_scope :open, :conditions => ["#{CmMntLogStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :my_mnts, lambda { |user| {:conditions => ["#{CmMntLog.table_name}.maintained_by_id=?", user]}}

  validates_presence_of :code, :name, :maintenance_time
  validates_uniqueness_of :code, :scope => :project_id
  validates_numericality_of :maintenance_time
  
  after_save :create_journal

  # Users the maintenance_log can be assigned to
  def assignable_users
    project.assignable_users
  end 

  def after_initialize
    if new_record?
      unless project.nil?
        self.status ||= CmMntLogStatus.default(project)
        self.type ||= CmMntLogType.default(project)
      end
    end
  end
  
  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  # Return true if the nc is closed, otherwise false
  def closed?
    self.status.is_closed?
  end

  def init_journal(user, notes = "")
    @current_journal ||= MlogJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_mnt_log_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmMntLog.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_mnt_log_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_mnt_log_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  def to_s; name end  

private
  def validate_on_create    #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Maintenance'), @project.id])
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
      code_in_table=CmMntLog.find_by_code(self.code)
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

