class AlterNcsTable < ActiveRecord::Migration
  def self.up
    add_column :cm_ncs, :nc_issue, :string, :limit => 10, :null => false
    add_column :cm_ncs, :originator, :string, :limit => 30, :null => false
    add_column :cm_ncs, :preventive_action, :text
    add_column :cm_changes_objects, :target_version_id, :integer
    add_column :cm_ncs_objects, :target_version_id, :integer
  end

  def self.down
    remove_column :cm_ncs, :preventive_action
    remove_column :cm_ncs, :nc_issue
    remove_column :cm_ncs, :originator
    remove_column :cm_changes_objects, :target_version_id
    remove_column :cm_ncs_objects, :target_version_id
  end
end
