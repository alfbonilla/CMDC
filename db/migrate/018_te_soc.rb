class TeSoc < ActiveRecord::Migration
  def self.up
    add_column :cm_reqs, :assumption, :text
    add_column :cm_reqs, :compliance, :integer
    add_column :cm_reqs_types, :soc_control, :boolean, :default => false, :null => false
    rename_column :cm_changes, :compatibility, :compliance
  end

  def self.down
    remove_column :cm_reqs, :compliance
    remove_column :cm_reqs, :assumption
    remove_column :cm_reqs_types, :soc_control
    rename_column :cm_changes, :compliance, :compatibility
  end
end
