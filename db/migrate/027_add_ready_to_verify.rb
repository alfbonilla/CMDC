class AddReadyToVerify < ActiveRecord::Migration
  def self.up
    add_column :cm_ncs_statuses, :is_ready_to_verify, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_ncs_statuses, :is_ready_to_verify
  end
end
