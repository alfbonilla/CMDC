class CmTest < ActiveRecord::Base
  include CmDocCountersHelper

  belongs_to :project
  belongs_to :type, :class_name => 'CmTestType', :foreign_key => 'type_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :classification, :class_name => 'CmTestClassification', :foreign_key => 'classification_id'
  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_test_campaigns_object, :class_name => 'CmTestCampaignsObject', :foreign_key => 'cm_test_id', :dependent => :delete_all
  has_many :cm_tests_objects, :class_name => 'CmTestsObject', :foreign_key => 'cm_test_id', :dependent => :delete_all
  has_many :cm_tests_tests, :order => 'execution_order', :dependent => :destroy
  has_many :cm_tests_parents, :class_name => 'CmTestsTest', :foreign_key => 'child_test_id', :dependent => :delete_all
  has_many :cm_reqs, :through => :cm_tests_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmReq'"
  has_many :cm_docs, :through => :cm_tests_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmDoc'"
  has_many :cm_test_scenarios, :through => :cm_tests_objects, :foreign_key => 'x_id', :conditions => "x_type = 'CmTestScenario'"
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id', :conditions => "cm_object_type = 'CmTest'", :dependent => :destroy
  
  acts_as_watchable
  attr_reader :current_journal
  attr_accessor :counter_type

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
        self.type ||= CmTestType.default(project)
        self.classification ||= CmTestClassification.default(project)
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

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_tests, self.project)
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


  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmTestJournal.new(:journalized => self, :user => user, :notes => notes)
    @Test_before_change = self.clone
  end

  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmTest.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
          @current_journal.details << JournalDetail.new(:property => 'attr',
                                                :prop_key => c,
                                                :old_value => @Test_before_change.send(c),
                                                :value => send(c)) unless send(c)==@Test_before_change.send(c)
      }
      @current_journal.save
    end
  end

  def to_s; name end

  private

  def validate_on_create   #unique_code
    #Get code again from Code Generator
    cm_test_type = CmTestType.find(self.type_id)

    if cm_test_type.blank?
      errors.add(:type_id, "has not a valid value!")
    else
      if self.counter_type == 0
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?', cm_test_type.name, self.project])
      else
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])
      end

      unless @cm_doc_counter.blank?
        new_value=@cm_doc_counter.counter + @cm_doc_counter.increment_by
        begin
          new_code=get_new_code(self.code, @cm_doc_counter.format, new_value,
            cm_test_type.acronym)
        rescue RuntimeError => e
          errors.add(:code, e.message)
          return
        end

        #At this point, the oldcode was correctly formed, but it could be different
        #because counter points to different code
        code_in_table=CmTest.find_by_code(self.code)
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