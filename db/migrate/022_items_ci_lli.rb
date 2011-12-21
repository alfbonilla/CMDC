class ItemsCiLli < ActiveRecord::Migration
  def self.up
    add_column :cm_items, :critical_item,  :boolean, :default => false, :null => false
    add_column :cm_items, :long_lead_item,  :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_items, :critical_item
    remove_column :cm_items, :long_lead_item
  end
end
