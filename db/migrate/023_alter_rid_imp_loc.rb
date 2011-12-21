class AlterRidImpLoc < ActiveRecord::Migration
  def self.up
    change_column_default(:cm_rids, :implementation_location, "")
  end

  def self.down
  end
end
