class AlterDocsTableExternalId < ActiveRecord::Migration
  def self.up
    add_column :cm_docs, :external_doc_id, :string, :limit => 30, :default => "", :null => false
    add_column :cm_docs, :applicable_version, :string, :limit => 10, :default => "", :null => false
  end

  def self.down
    remove_column :cm_docs, :external_doc_id
    remove_column :cm_docs, :applicable_version
  end
end
