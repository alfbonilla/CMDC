class AddExpectedIdNcs < ActiveRecord::Migration
  def self.up
    add_column :cm_ncs, :rlse_expected_id, :integer
    add_column :cm_ncs, :impacted_items, :text
  end

  def self.down
    remove_column :cm_ncs, :rlse_expected_id
    remove_column :cm_ncs, :impacted_items
  end
end