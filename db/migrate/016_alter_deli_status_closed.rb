class AlterDeliStatusClosed < ActiveRecord::Migration
  def self.up
    add_column :cm_delivery_statuses, :is_closed, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_delivery_statuses, :is_closed
  end
end
