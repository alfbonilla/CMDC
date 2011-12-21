class RefineIssuesRelation < ActiveRecord::Migration
  #This script re-creates ALL the tables of the plugin, deleting ALL the data
  #It has an update for all the rows inserted, setting the project as project_id = '4'
  def self.up
    create_table :cm_objects_issues, :force => true do |t|
      t.column :cm_object_id, :integer, :null => false
      t.column :issue_id, :integer, :null => false
      t.column :cm_object_type, :string, :size => 10, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_objects_issues", ["issue_id", "cm_object_id", "cm_object_type"],
          :name => "objects_issues_indx", :unique => true

#    rids=CmRidsIssue.find(:all)
#    rids.each do |rid|
#      CmObjectsIssue.create(:cm_object_id => rid.cm_rid_id, :issue_id => rid.issue_id,
#        :cm_object_type => "CmRid", :created_on => rid.updated_on, :author_id => rid.author_id,
#        :description => rid.description)
#    end

#    risks=CmRisksIssue.find(:all)
#    risks.each do |risk|
#      CmObjectsIssue.create(:cm_object_id => risk.cm_risk_id, :issue_id => risk.issue_id,
#        :cm_object_type => "CmRisk", :created_on => risk.created_on, :author_id => risk.author_id,
#        :description => risk.description)
#    end

#    items=CmItemsIssue.find(:all)
#    items.each do |item|
#      CmObjectsIssue.create(:cm_object_id => item.cm_item_id, :issue_id => item.issue_id,
#        :cm_object_type => "CmItem", :created_on => item.created_on, :author_id => item.author_id,
#        :description => item.description)
#    end

#    boards=CmBoardsIssue.find(:all)
#    boards.each do |board|
#      CmObjectsIssue.create(:cm_object_id => board.cm_board_id, :issue_id => board.issue_id,
#        :cm_object_type => "CmBoard", :created_on => board.created_on, :author_id => board.author_id,
#        :description => board.description)
#    end

#    ncs=CmNcsObject.find(:all, :conditions => ['x_type=?', "Issue"])
#    ncs.each do |nc|
#      CmObjectsIssue.create(:cm_object_id => nc.cm_nc_id, :issue_id => nc.x_id,
#        :cm_object_type => "CmNc", :created_on => nc.created_on, :author_id => nc.author_id)
#    end

#    CmNcsObject.delete_all(:x_type => "Issue")

#    changes=CmChangesObject.find(:all, :conditions => ['x_type=?', "Issue"])
#    changes.each do |change|
#      CmObjectsIssue.create(:cm_object_id => change.cm_change_id, :issue_id => change.x_id,
#        :cm_object_type => "Cmchange", :created_on => change.created_on, :author_id => change.author_id)
#    end
#
#    CmChangesObject.delete_all(:x_type => "Issue")

    drop_table :cm_rids_issues
    drop_table :cm_risks_issues
    drop_table :cm_items_issues
    drop_table :cm_boards_issues
    
  end

  def self.down
    drop_table :cm_objects_issues
  end
end
