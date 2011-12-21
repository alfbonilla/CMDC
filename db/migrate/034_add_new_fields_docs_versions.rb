class AddNewFieldsDocsVersions < ActiveRecord::Migration

  def self.up

    add_column :cm_docs_versions, :milestone, :string

    add_column :cm_docs_versions, :delivery_date, :datetime

  end


  def self.down

    remove_column :cm_docs_versions, :milestone

    remove_column :cm_docs_versions, :delivery_date

  end

end