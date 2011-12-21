class CmDelivery < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :status, :class_name => 'CmDeliveryStatus', :foreign_key => 'status_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :approver, :class_name => 'User', :foreign_key => 'approved_by'
  belongs_to :release, :class_name => 'Version', :foreign_key => 'release_id'
  belongs_to :source_company, :class_name => 'CmCompany', :foreign_key => 'from_company'
  belongs_to :target_company, :class_name => 'CmCompany', :foreign_key => 'to_company'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_deliveries_objects, :foreign_key => 'cm_delivery_id', :dependent => :destroy

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable

  attr_reader :current_journal
  attr_accessor :counter_type

  named_scope :open, :conditions => ["#{CmDeliveryStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :my_deliveries, lambda { |user| {:conditions => ["#{CmDelivery.table_name}.approved_by=?", user]}}
  
  validates_presence_of :code, :name
  validate :closed_statuses_management
  validates_uniqueness_of :code, :scope => :project_id

  after_save :create_journal

  def after_initialize
    #Rails error when model fails (eg: validate_uniqueness... Solved in 2.3.6)
    if new_record?
      unless project.nil?
        self.status ||= CmDeliveryStatus.default(project)
      end
    end
  end

  #
  # Journal Functionality Implementation
  #
  def after_save
    reload
  end

  # Return true if the delivery is closed, otherwise false
  def closed?
    self.status.is_closed?
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmdeliveryJournal.new(:journalized => self, :user => user, :notes => notes)
    @delivery_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmDelivery.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                            :prop_key => c,
                                            :old_value => @delivery_before_change.send(c),
                                            :value => send(c)) unless send(c)==@delivery_before_change.send(c)
      }     
      @current_journal.save
    end
  end

  def attachment_removed(obj)
    journal = init_journal(User.current)
    journal.notes = journal.notes + "* Attachment " + obj.filename + " deleted!"
    journal.save
  end


  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_deliveries, self.project)
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = project.notified_users
    # Author and assignee are always notified unless they have been locked
    notified << author if author && author.active?
    notified << approver if approver && approver.active?
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified.collect(&:mail)
  end

  def to_s; self.name end

  private

  def validate_on_create   #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['id=? and project_id=?', self.counter_type, self.project])

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
      code_in_table=CmDelivery.find_by_code(self.code)
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

  def closed_statuses_management
    # Do not validate for new records!
    unless new_record?
      new_status = CmDeliveryStatus.find(@attributes['status_id'])

      #If the delivery is closed and remains closed, modifications not allowed
      if self.status.is_closed and new_status.is_closed
        errors.add(:status_id, "is closed. Delivery can not be modified. Change status first!")
      end
    end
  end

end
