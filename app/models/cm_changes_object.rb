class CmChangesObject < ActiveRecord::Base
  belongs_to :cm_change, :class_name => 'CmChange', :foreign_key => 'cm_change_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :target_version, :class_name => 'Version', :foreign_key => 'target_version_id'
  belongs_to :req, :class_name => 'CmReq', :foreign_key => 'x_id'

  OBJECT_TYPES = %w(CmBoard CmItem CmDoc CmReq)

  validates_presence_of :cm_change_id, :x_id, :x_type
  validates_uniqueness_of :x_id, :scope => [:x_id, :cm_change_id, :x_type]

  def to_s; id.to_s end
end
