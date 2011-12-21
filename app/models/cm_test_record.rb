class CmTestRecord < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'witnessed_by'
  belongs_to :cm_test_campaigns_object, :class_name => 'CmTestCampaignsObject', :foreign_key => 'cm_test_campaigns_object_id'
  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_ncs_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmTestRecord'",
              :dependent => :destroy

  acts_as_attachable :after_remove => :attachment_removed
  
  validates_presence_of :code

  attr_reader :current_journal
  after_save :create_journal

  # Journal Functionality Implementation
  def after_save
    reload
  end


  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id=?", true, project])
  end

  def init_journal(user, notes = "")
    #Control for not saving when not desired
    if notes=="CM/DC-NotSave"
      @Test_save=false
      notes=""
    else
      @Test_save=true
    end

    @current_journal ||= CmTestJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_test_record_before_change = self.clone

    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end

  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmTestRecord.column_names - %w(id project_id created_on updated_on)).each {|c|
          @current_journal.details << JournalDetail.new(:property => 'attr',
                                                :prop_key => c,
                                                :old_value => @cm_test_record_before_change.send(c),
                                                :value => send(c)) unless send(c)==@cm_test_record_before_change.send(c)
      }
      @current_journal.save
    end
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end

  def to_s; code end

  private

 
   def validate_on_create   #unique_code

    is_first_execution = CmTestRecord.find_by_code(self.code)
    if ! is_first_execution.nil?
      return
    end
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Test Record'), @project.id])
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
      code_in_table=CmTestRecord.find_by_code(self.code)
      
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