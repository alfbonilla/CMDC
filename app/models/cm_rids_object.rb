class CmRidsObject < ActiveRecord::Base
  belongs_to :cm_rid, :class_name => 'CmRid', :foreign_key => 'cm_rid_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :req, :class_name => 'CmReq', :foreign_key => 'x_id'
  belongs_to :target_version, :class_name => 'Version', :foreign_key => 'target_version_id'

  OBJECT_TYPES = %w(CmBoard CmReq)

  validates_presence_of :cm_rid_id, :x_id, :x_type
  validates_uniqueness_of :x_id, :scope => [:x_id, :cm_rid_id, :x_type]

  def to_s; id.to_s end
end
