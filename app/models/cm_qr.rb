class CmQr < ActiveRecord::Base
  include CmDocCountersHelper
  include CmCommonHelper
  
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :type, :class_name => 'CmQrType', :foreign_key => 'type_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :cm_ncs

  acts_as_attachable :after_remove => :attachment_removed
  acts_as_watchable

  attr_reader :current_journal
  
  QR_STATUSES = %w(Accepted Rejected Accepted_with_NCs)
  #List of objects that can generate a QR
  QR_OBJECT_TYPES = %w(PurchaseOrder InventoryItem Document Delivery)

  validates_presence_of :code
  validates_inclusion_of :status, :in => QR_STATUSES
  validates_inclusion_of :x_type, :in => QR_OBJECT_TYPES
  validates_uniqueness_of :code, :scope => :project_id
 
  after_save :create_journal

  # Users the NC can be assigned to
  def assignable_users
    project.assignable_users
  end
  
  # Journal Functionality Implementation
  def after_save
    reload
  end

  def init_journal(user, notes = "")
    @current_journal ||= CmQrJournal.new(:journalized => self, :user => user, :notes => notes)
    @cm_qr_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end  
      
  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmQr.column_names - %w(id author_id project_id created_on updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_qr_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_qr_before_change.send(c)
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
    (usr || User.current).allowed_to?(:view_cm_qrs, self.project)
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
  def validate_on_create    #unique_code
    #Get code again from Code Generator
    @cm_doc_counter = CmDocCounter.find(:first,
      :conditions => ['cmdc_object=? and project_id=?',
        change_cmdc_object_to_i('Quality Record'), @project.id])
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
      code_in_table=CmQr.find_by_code(self.code)
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