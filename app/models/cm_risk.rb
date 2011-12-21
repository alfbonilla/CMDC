class CmRisk < ActiveRecord::Base
  include CmRisksHelper
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :status, :class_name => 'CmRiskStatus', :foreign_key => 'status_id'
  belongs_to :type, :class_name => 'CmRiskType', :foreign_key => 'type_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_objects_issues, :foreign_key => 'cm_object_id',
              :conditions => "cm_object_type = 'CmRisk'", :dependent => :destroy
  
  acts_as_watchable

  attr_reader :current_journal
  
  named_scope :closed, :conditions => ["#{CmRiskStatus.table_name}.is_closed = ?", true], :include => :status
  named_scope :my_project, lambda { |project| {:conditions => ["#{CmRisk.table_name}.project_id=?", project]}}
  named_scope :open, :conditions => ["#{CmRiskStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :my_risks, lambda { |user| {:conditions => ["#{CmRisk.table_name}.assigned_to_id=?", user]}}
  
  validates_presence_of :code, :name, :probability, :detection_date, :impact_ini_date, :impact_end_date
  validates_uniqueness_of :code, :scope => :project_id
  
  validate :closed_statuses_management
  validate :ini_and_end_dates

  after_save :create_journal

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_risks, self.project)
  end

  def after_initialize
    if new_record?
      # set default values for new records only
      unless project.nil?
        self.status ||= CmRiskStatus.default(project)
        self.type ||= CmRiskType.default(project)
      end
    end
  end

  # Return true if the Risk is closed, otherwise false
  def closed?
    self.status.is_closed?
  end

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  def before_save
#   If RISK is closed, no calculation are done!
#   Risk Exposure Assignment JUST when impact or probability change
    new_status = CmRiskStatus.find(@attributes['status_id'])
    unless new_status.is_closed?
      if @attributes['impact'] != self.impact or
         @attributes['probability'] != self.probability
        self.risk_exposure=calculate_exposure(self.impact, self.probability)
      end

      self.priority_ranking = calculate_priority(self.impact_ini_date,
                                  self.impact_end_date, self.risk_exposure)
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmRiskJournal.new(:journalized => self, :user => user, :notes => notes)
    @risk_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmRisk.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @risk_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@risk_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_risks, self.project)
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

  def to_s; name end

  private

  def closed_statuses_management
    new_status = CmRiskStatus.find(@attributes['status_id'])

    #If the Risk passes from some non closed status to a closed one
    if new_record? and new_status.is_closed
        self.closing_date = Time.now
    end

    if new_status.is_closed and (self.status.is_opened or self.status.blank?)
        self.closing_date = Time.now
    end

    #If the Risk passes from some closed status to a non closed one
    if self.status.is_closed and new_status.is_opened
      self.closing_date = nil
    end
  end

  def ini_and_end_dates
    if not self.impact_ini_date.nil?  and not self.impact_end_date.nil?
      if self.impact_ini_date > self.impact_end_date
        errors.add(:impact_end_date, "is lower than the initial one ")
      end
    end
  end

  def validate_on_create   #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Risk'), @project.id])
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
      code_in_table=CmRisk.find_by_code(self.code)
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
