class AddTextFieldsNcs < ActiveRecord::Migration
  def self.up
    add_column :cm_ncs, :violated_reqs, :text
    add_column :cm_ncs, :reference_docs, :text
    add_column :cm_ncs, :failed_tests, :text
    remove_column :cm_ncs, :cm_item_group_id
  end

  def self.down
    remove_column :cm_ncs, :violated_reqs
    remove_column :cm_ncs, :reference_docs
    remove_column :cm_ncs, :failed_tests
    add_column :cm_ncs, :cm_item_group_id, :integer
  end
end