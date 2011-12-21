class CmSmrsAffectedFile < ActiveRecord::Base
  belongs_to :project
  belongs_to :smr, :class_name => 'CmSmr', :foreign_key => 'cm_smr_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  
  validates_presence_of :cm_smr_id, :source_revision, :final_revision
  validate :revisions

  def revisions
    #final can not be lower than source
    errors.add(:final_revision, "can't be lower than the source revision!") if self.final_revision < self.source_revision
    #both can not be the same
    errors.add(:final_revision, "can't be the same than the source revision!") if self.final_revision == self.source_revision
  end

  def to_s; self.id.to_s end
end
