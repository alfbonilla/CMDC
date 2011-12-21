class CreateReqs < ActiveRecord::Migration
  #CM/DC Requirements datamodel
  #New column in RIDS table
  def self.up
    create_table :cm_reqs, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 100, :default => "", :null => false
      t.column :description, :text
      t.column :version, :string
      t.column :type_id, :integer
      t.column :status, :integer      
      t.column :classification_id, :integer
      t.column :subsystem_id, :integer
      t.column :assigned_to_id, :integer
      t.column :verification_method, :integer
      t.column :comments, :text
      t.column :display_order, :integer
      t.column :place_in_doc, :string
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_reqs", ["project_id"], :name => "cm_reqs_project_id"

    create_table :cm_reqs_reqs, :force => true do |t|
      t.column :cm_req_id, :integer, :null => false
      t.column :child_req_id, :integer, :null => false
      t.column :relation_type, :integer
      t.column :created_on, :datetime, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_reqs_reqs", ["cm_req_id", "child_req_id"], :name => "reqs_reqs_indx", :unique => true

    create_table :cm_reqs_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :level, :integer, :default=> 0, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_reqs_classifications, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    add_column :cm_rids, :assigned_to_id, :integer
  end

  def self.down
    drop_table :cm_reqs
    drop_table :cm_reqs_reqs
    drop_table :cm_reqs_types
    drop_table :cm_reqs_classifications
    
    remove_column :cm_rids, :assigned_to_id
  end
end
