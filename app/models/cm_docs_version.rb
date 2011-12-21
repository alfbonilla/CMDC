class CmDocsVersion < ActiveRecord::Base
  belongs_to :cm_doc
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :status, :class_name => 'CmDocStatus', :foreign_key => 'status_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'

  named_scope :open, :conditions => ["#{CmDocStatus.table_name}.is_closed = ?", false], :include => :status
  named_scope :my_docs, lambda { |user| {:conditions => ["#{CmDocsVersion.table_name}.assigned_to_id=?", user]}}
  
  validates_presence_of :version
  validates_uniqueness_of :version, :scope => :cm_doc_id

  before_destroy :check_integrity, :remove_applicability
  after_save :set_applicability, :create_journal

  acts_as_watchable

  def init_journal(user, notes = "")
    @current_journal ||= CmdocJournal.new(:journalized => self.cm_doc, :user => user, :notes => notes)
    @cm_doc_v_before_change = self.clone
    # Make sure updated_on is updated when adding a note.
    updated_on_will_change!
    @current_journal
  end

  def create_journal
    if @current_journal
      # attributes changes: all columns except the ones included in the sentence
      (CmDocsVersion.column_names - %w(id cm_doc_id author_id updated_on)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @cm_doc_v_before_change.send(c),
                                                      :value => send(c)) unless send(c)==@cm_doc_v_before_change.send(c)
      }
      @current_journal.save
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_cm_docs, self.cm_doc.project)
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = cm_doc.project.notified_users
    # Author and assignee are always notified unless they have been locked
    notified << author if author && author.active?
    notified << assignee if assignee && assignee.active?
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified.collect(&:mail)
  end

  private

  def set_applicability
    # Set all versions for this doc as not applicable and update applicable_version field in cm_doc
    if self.applicable
      CmDocsVersion.update_all("applicable = false", "cm_doc_id = #{self.cm_doc_id} and id <> #{self.id}")
      CmDoc.update(self.cm_doc_id, :applicable_version => self.version)
    else
      if @cm_doc_v_before_change
        CmDoc.update(self.cm_doc_id, :applicable_version => "") if @cm_doc_v_before_change.applicable
      end
    end
  end

  def remove_applicability
    if self.applicable
      CmDoc.update(self.cm_doc_id, :applicable_version => "")
    end
  end

  def check_integrity
    dl=CmDeliveriesObject.find(:first, :conditions => ["x_id=? and x_type=? and rel_string=?",
              self.cm_doc_id, "CmDoc", self.version])
    if dl
      raise "Can't delete doc version because was delivered in " + dl.delivery.code
    end
  end
end