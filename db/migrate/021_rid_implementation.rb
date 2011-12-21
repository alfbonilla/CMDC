class RidImplementation < ActiveRecord::Migration
  def self.up
    add_column :cm_rids, :implementation_location, :string, :null => false
    add_column :cm_rids, :reviewed,  :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_rids, :implementation_location
    remove_column :cm_rids, :reviewed
  end
end
