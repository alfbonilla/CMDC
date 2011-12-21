class CreateDocsVersions < ActiveRecord::Migration
  def self.up
    create_table :cm_docs_versions, :force => true do |t|
      t.column :cm_doc_id, :integer, :null => false
      t.column :version, :string, :limit => 10, :default => "", :null => false
      t.column :applicable, :boolean, :default => 0,  :null => false
      t.column :updated_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :comments, :string
    end
    add_column :cm_doc_statuses, :is_received, :boolean, :default => 0, :null => false
    change_column :cm_tempo_reqs, :action, :string, :limit => 7, :null => false

    CmTempoReq.update_all( "action = 'DELETE'", "action = 'DEL'" )

  end

  def self.down
    drop_table :cm_docs_versions
    remove_column :cm_doc_statuses, :is_received
    change_column :cm_tempo_reqs, :action, :string, :limit => 5, :null => false

    CmTempoReq.update_all( "action = 'DEL'", "action = 'DELETE'" )
  end
end
