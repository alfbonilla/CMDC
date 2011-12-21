class AlterBoardType < ActiveRecord::Migration
  def self.up
    change_column :cm_boards, :type_id, :integer, :default => 0, :null => true
  end

  def self.down
    change_column :cm_boards, :type_id, :string, :limit => 10, :null => false
  end
end
