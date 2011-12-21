class CmItemsObject < ActiveRecord::Base
  belongs_to :cm_item, :class_name => 'CmItem', :foreign_key => 'cm_item_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :cm_doc, :class_name => 'CmDoc', :foreign_key => 'x_id'
  belongs_to :target_version, :class_name => 'Version', :foreign_key => 'target_version_id'

  OBJECT_TYPES = %w(CmDoc)

  validates_presence_of :cm_item_id, :x_id, :x_type
  validates_uniqueness_of :x_id, :scope => [:x_id, :cm_item_id, :x_type]

  def to_s; id.to_s end
end
