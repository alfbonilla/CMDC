class CmWa < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :nonConformance, :class_name => 'CmNc', :foreign_key => 'cm_nc_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :rlse_removed, :class_name => 'Version', :foreign_key => 'rlse_removed_id'

  has_many :journals, :as => :journalized, :dependent => :destroy

  acts_as_attachable :after_remove => :attachment_removed

  WA_STATUSES = %w(Open Implemented Removed)
  WA_TYPES = %w(Swpatch Manualprotocol Swpatchmanualprotocol)

  attr_reader :current_journal

  validates_presence_of :cm_wa_code
  validates_inclusion_of :status, :in => WA_STATUSES
  validates_inclusion_of :wa_type, :in => WA_TYPES
  validates_uniqueness_of :cm_wa_code, :scope => :project_id

  after_save :create_journal

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmWaJournal.new(:journalized => self, :user => user, :notes => notes)
    @wa_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmWa.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @wa_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@wa_before_change.send(c)
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

  def validate_on_create   #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Work Around'), @project.id])
    unless @cm_doc_counter.blank?
      new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
      begin
        new_code=get_new_code(self.cm_wa_code, @cm_doc_counter.format, new_value)
      rescue RuntimeError => e
        errors.add(:cm_wa_code, e.message)
        return
      end
      #At this point, the oldcode was correctly formed, but it could be different
      #because counter points to different code
      code_in_table=CmWa.find_by_cm_wa_code(self.cm_wa_code)
      if code_in_table.nil?
        # code not taken. Continue with received value and update counter
        if self.cm_wa_code == new_code
          # Update code counter
          CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
        end
      else
        # code already taken
        if self.cm_wa_code != new_code
          # Code already exists, advise user of code changing
          self.cm_wa_code = new_code
        end
        # Update code counter anyway for next code generation
        CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
      end
    end
  end
end