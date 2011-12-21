class NcsRefine < ActiveRecord::Migration
  def self.up
    rename_column :cm_ncs, :affected_items, :impact_notes
    remove_column :cm_ncs, :affected_design
    remove_column :cm_ncs, :failure_tests
    remove_column :cm_ncs, :related_docs
  end

  def self.down
    rename_column :cm_ncs, :impact_notes, :affected_items
    add_column :cm_ncs, :affected_design, :text
    add_column :cm_ncs, :failure_tests, :text
    add_column :cm_ncs, :related_docs, :text
  end
end
