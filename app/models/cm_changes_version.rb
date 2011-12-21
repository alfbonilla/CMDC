class CmChangesVersion < ActiveRecord::Base
  belongs_to :cm_change
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  validates_presence_of :version
  validates_uniqueness_of :version, :scope => :cm_change_id

  before_destroy :remove_applicability
  after_save :set_applicability

  private

  def set_applicability
    # Set all versions for this change as not applicable and update applicable_version field in cm_change
    if self.applicable
      CmChangesVersion.update_all("applicable = false", "cm_change_id = #{self.cm_change_id} and id <> #{self.id}")
      CmChange.update(self.cm_change_id, :applicable_version => self.version)
    end
  end

  def remove_applicability
    if self.applicable
      CmChange.update(self.cm_change_id, :applicable_version => "")
    end
  end
end