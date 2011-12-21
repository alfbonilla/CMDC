class DellNewFieldsDocsVersions < ActiveRecord::Migration

  def self.up

    remove_column :cm_docs_versions, :milestone

    remove_column :cm_docs_versions, :delivery_date
   

  end

  def self.down

    add_column :cm_docs_versions, :milestone, :string

    add_column :cm_docs_versions, :delivery_date, :datetime

  end

end