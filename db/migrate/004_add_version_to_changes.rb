class AddVersionToChanges < ActiveRecord::Migration
  def self.up
    add_column :cm_changes, :affected_version, :string, :limit => 20, :null => false
  end

  def self.down
    remove_column :cm_changes, :affected_version
  end
end
