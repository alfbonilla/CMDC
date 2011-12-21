class CmTestScenario < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  has_many :cm_tests_objects, :class_name => 'CmTestsObject',:foreign_key => 'x_id', :conditions => "x_type = 'CmTestScenario'"
  has_many :journals, :as => :journalized, :dependent => :destroy

  validates_presence_of :name
  validates_length_of :name, :maximum => 100
  
  validates_uniqueness_of :code, :scope => :project_id

  attr_reader :current_journal
  after_save :create_journal

  before_destroy :check_integrity

  # Journal Functionality Implementation
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmTestScenarioJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_test_scenario_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end

  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmTestScenario.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_test_scenario_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_test_scenario_before_change.send(c)
      }
      @current_journal.save
    end
  end

  #TODO:
  #Check that default is not used and delete it.
  #
  def self.default(project)
#    find(:first, :conditions =>["is_default=? and project_id=?", true, project])
  end

  def to_s; name end

  private

  def validate_on_create    #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Test Scenario'), @project.id])
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
      code_in_table=CmTestScenario.find_by_code(self.code)
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

  def just_one_default
#    if(self.is_default)
#      @testScenario=CmTestScenario.find(:first, :conditions =>["is_default=? and project_id=?", true, self.project_id])
#      errors.add(:is_default, "already assigned to " + @testScenario.name) unless (@testScenario.nil?)
#    end
  end

  def check_integrity
    #TODO:
    #Add Scenario_id field in cm_test_campaign table!!!!!!!!!!!!1
    #
    #
#    if CmTest.find(:first, :conditions => ["Scenario_id=?", self.id])
#      raise "Can't delete Scenario because there are Tests using it!!"
#    end
  end
end