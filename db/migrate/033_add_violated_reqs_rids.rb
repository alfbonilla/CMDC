class AddViolatedReqsRids < ActiveRecord::Migration
  def self.up
    add_column :cm_rids, :violated_reqs, :text
  end

  def self.down
    remove_column :cm_rids, :violated_reqs
  end
end