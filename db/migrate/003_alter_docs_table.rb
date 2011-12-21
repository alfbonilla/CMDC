class AlterDocsTable < ActiveRecord::Migration
  def self.up
    add_column :cm_docs, :assigned_to_id, :integer, :default => 0
  end

  def self.down
    remove_column :cm_docs, :assigned_to_id
  end
end
