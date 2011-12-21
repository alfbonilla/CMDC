class CreateItemsObjects < ActiveRecord::Migration
  def self.up
    create_table :cm_items_objects, :force => true do |t|
      t.column :cm_item_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 50, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :target_version_id, :integer
      t.column :category, :integer
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_column :cm_docs, :baseline, :integer
  end

  def self.down
    drop_table :cm_items_objects
    remove_column :cm_docs, :baseline
  end
end
