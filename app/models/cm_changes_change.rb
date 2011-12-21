class CmChangesChange < ActiveRecord::Base
  belongs_to :parent_change, :class_name => 'CmChange', :foreign_key => 'parent_change_id'
  belongs_to :child_change, :class_name => 'CmChange', :foreign_key => 'child_change_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  validate_presences_of :parent_change_id, :child_change_id
  validates_uniqueness_of :child_change_id, :scope => [:child_change_id, :parent_change_id]

  def to_s; description end
end
