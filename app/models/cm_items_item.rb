class CmItemsItem < ActiveRecord::Base
  belongs_to :parent_item, :class_name => 'CmItem', :foreign_key => 'cm_item_id'
  belongs_to :child_item, :class_name => 'CmItem', :foreign_key => 'child_item_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  ITEM_RELATIONS = %w(belongs_to_stock integrated_in installed_on)

  validate_presences_of :cm_item_id, :child_item_id
  validates_uniqueness_of :child_item_id, :scope => [:child_item_id, :cm_item_id]
  validates_inclusion_of :priority, :in => ITEM_RELATIONS

  validate :relation_type

  def relation_type
    # cm_item_id has to be STOCK type
    if self.relation_type == "belongs_to_stock" and self.parent_item.type.name != "Stock"
      errors.add(:relation_type, "Stock relation requires to select the Stock Type first")
    end
  end

  def to_s; description end
end
