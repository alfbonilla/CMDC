class CmSmr < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :nonConformance, :class_name => 'CmNc', :foreign_key => 'cm_nc_id'
  belongs_to :change, :class_name => 'CmChange', :foreign_key => 'cm_change_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  has_many :cm_smrs_affected_files, :dependent => :destroy
  has_many :journals, :as => :journalized, :dependent => :destroy

  acts_as_attachable :after_remove => :attachment_removed

  attr_reader :current_journal

  validates_presence_of :smr_code
  validate :nc_or_change
  validates_uniqueness_of :smr_code, :scope => :project_id

  after_save :create_journal

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmSmrJournal.new(:journalized => self, :user => user, :notes => notes)
    @smr_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmSmr.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @smr_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@smr_before_change.send(c)
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

  def nc_or_change
    if self.cm_nc_id.blank? and self.cm_change_id.blank?
      errors.add :smr_code, "has to be associated to a change OR to a non-conformance!!"
    end
    self.cm_change_id = 0 if self.cm_change_id.nil?
    self.cm_nc_id = 0 if self.cm_nc_id.nil?
  end

  def validate_on_create  #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
            :conditions => ['cmdc_object=? and project_id=?',
                    change_cmdc_object_to_i('SMR'), @project.id])
    unless @cm_doc_counter.blank?
      new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
      begin
        new_code=get_new_code(self.smr_code, @cm_doc_counter.format, new_value)
      rescue RuntimeError => e
        errors.add(:smr_code, e.message)
        return
      end
      #At this point, the oldcode was correctly formed, but it could be different
      #because counter points to different code
      code_in_table=CmSmr.find_by_smr_code(self.smr_code)
      if code_in_table.nil?
        # code not taken. Continue with received value and update counter
        if self.smr_code == new_code
          # Update code counter
          CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
        end
      else
        # code already taken
        if self.smr_code != new_code
          # Code already exists, advise user of code changing
          self.smr_code = new_code
        end
        # Update code counter anyway for next code generation
        CmDocCounter.update(@cm_doc_counter.id, :counter => new_value)
      end
    end
  end
end