class CreateSubsysTable < ActiveRecord::Migration
  def self.up
    create_table :cm_subsystems, :force => true do |t|
      t.column :code, :string, :limit => 10, :default => "", :null => false
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    add_column :cm_docs, :subsystem_id, :integer
  end

  def self.down
    drop_table :cm_subsystems
    remove_column :cm_docs, :subsystem_id
  end
end
