class DocCounterRefine < ActiveRecord::Migration
  def self.up
    add_column :cm_doc_counters, :cmdc_object,  :integer, :default => 0, :null => false
    add_column :cm_doc_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_docs, :approval_level, :string, :limit => 1, :default => "", :null => false
    add_column :cm_board_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_ncs_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_change_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_reqs_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_test_types, :acronym, :string, :limit => 10, :default => "", :null => false
    add_column :cm_item_types, :acronym, :string, :limit => 10, :default => "", :null => false
  end

  def self.down
    remove_column :cm_doc_counters, :cmdc_object
    remove_column :cm_doc_types, :acronym
    remove_column :cm_docs, :approval_level
    remove_column :cm_board_types, :acronym
    remove_column :cm_ncs_types, :acronym
    remove_column :cm_change_types, :acronym
    remove_column :cm_reqs_types, :acronym
    remove_column :cm_test_types, :acronym
    remove_column :cm_item_types, :acronym
  end
end
