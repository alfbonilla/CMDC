class AlterRidsTable < ActiveRecord::Migration
  def self.up
    remove_column :cm_rids, :name
  end

  def self.down
    add_column :cm_rids, :name, :string, :default => "", :null => false
  end
end
