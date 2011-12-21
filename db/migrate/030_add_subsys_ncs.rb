class AddSubsysNcs < ActiveRecord::Migration
  def self.up
    add_column :cm_ncs, :subsystem_id, :integer
  end

  def self.down
    remove_column :cm_ncs, :subsystem_id
  end
end