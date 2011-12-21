class AlterDocsDil < ActiveRecord::Migration
  def self.up
    add_column :cm_docs, :deliverable, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :cm_docs, :deliverable
  end
end
