class AlterRidsCategory < ActiveRecord::Migration
  def self.up
    unless CmRid.table_name.to_s.singularize.camelcase.constantize.column_names.include?("category")
      add_column :cm_rids, :category, :integer, :default => false
    else
      announce "Colunm Category already exist in table"
    end
  end

  def self.down
    remove_column :cm_rids, :category
  end
end
