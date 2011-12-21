class CmTestType < ActiveRecord::Base
  before_destroy :check_integrity
  belongs_to :project

  has_many :journals, :as => :journalized, :dependent => :destroy

  validates_presence_of :name, :level
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 30
  validate :just_one_default

  attr_reader :current_journal
  after_save :create_journal

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
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
    @Test_before_change = self.clone

    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
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

  def just_one_default
    if(self.is_default)
      if new_record?
        @testType=CmTestType.find(:first, :conditions =>["is_default=? and project_id in (?,?)",
            true, 0, self.project_id])
      else
        @testType=CmTestType.find(:first, :conditions =>["is_default=? and id<>? and project_id in (?,?)",
            true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @testType.name) unless (@testType.nil?)
    end
  end

  def check_integrity
    if CmTest.find(:first, :conditions => ["type_id=?", self.id])
      raise "Can't delete Type because there are Tests using it!!"
    end
  end
end