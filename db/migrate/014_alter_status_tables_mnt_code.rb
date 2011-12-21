class AlterStatusTablesMntCode < ActiveRecord::Migration
  def self.up
    add_column :cm_mnt_logs, :code, :string, :limit => 50, :null => false
    add_column :cm_doc_statuses, :is_closed, :boolean, :default => false, :null => false
    add_column :cm_mnt_log_statuses, :is_closed, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_mnt_logs, :code
    remove_column :cm_doc_statuses, :is_closed, :boolean, :default => false, :null => false
    remove_column :cm_mnt_log_statuses, :is_closed, :boolean, :default => false, :null => false
  end
end
