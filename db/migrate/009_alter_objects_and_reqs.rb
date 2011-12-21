class AlterObjectsAndReqs < ActiveRecord::Migration
  def self.up
    add_index "cm_objects_issues", ["cm_object_id"], :name => "cm_object_issues_id"

    add_column :cm_reqs, :no_ascendants, :boolean
    add_column :cm_reqs, :no_descendants, :boolean
    add_column :cm_reqs, :optional, :boolean

    remove_column :cm_ncs, :violated_reqs

    create_table :cm_tempo_reqs, :id => false, :force => true do |t|
      t.column :req_id, :integer
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

    add_index "cm_tempo_reqs", ["req_id"], :name => "cm_tempo_reqs_id"

    create_table :cm_tempo_reqs_objects, :force => true do |t|
      t.column :req_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 30, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :target_version_id, :integer
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

  end

  def self.down
    drop_index :cm_object_issues_id

    drop_table :cm_tempo_reqs
    drop_table :cm_tempo_reqs_objects

    remove_column :cm_reqs, :no_deriverable
    remove_column :cm_reqs, :no_descendants

    add_column :cm_ncs, :violated_reqs, :text
  end
end
