class AlterTempoReqs < ActiveRecord::Migration
  def self.up

    drop_table :cm_tempo_reqs

    # Removed columns not considered for changing the status of req
    create_table :cm_tempo_reqs, :force => true do |t|
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
      t.column :no_ascendants, :boolean
      t.column :no_descendants, :boolean
      t.column :optional, :boolean
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
      t.column :action, :string, :limit => 5, :null => false
    end

    add_index "cm_tempo_reqs", ["req_id"], :name => "cm_tempo_reqs_req_id"

    drop_table :cm_tempo_reqs_objects

    create_table :cm_tempo_reqs_reqs, :force => true do |t|
      t.column :cm_req_id, :integer, :null => false
      t.column :child_req_id, :integer, :null => false
      t.column :relation_type, :integer
      t.column :description, :string, :default => "", :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :action, :string, :limit => 5, :null => false
    end
  end

  def self.down
    # This operations will never taken down
  end
end
