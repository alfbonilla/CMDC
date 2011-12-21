class CmPoDetail < ActiveRecord::Base
  
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :item, :class_name => 'CmItem', :foreign_key => 'cm_item_id'
  belongs_to :purchase_order, :class_name => 'CmPurchaseOrder', :foreign_key => 'cm_purchase_order_id'

  validates_uniqueness_of :cm_item_id, :scope => [:cm_item_id, :cm_purchase_order_id]
  validates_presence_of :quantity, :cost_per_unit
 
  def to_s; name end      
end