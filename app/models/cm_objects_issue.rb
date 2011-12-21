class CmObjectsIssue < ActiveRecord::Base
  belongs_to :doc, :class_name => 'CmDoc', :foreign_key => 'cm_object_id'
  belongs_to :rid, :class_name => 'CmRid', :foreign_key => 'cm_object_id'
  belongs_to :risk, :class_name => 'CmRisk', :foreign_key => 'cm_object_id'
  belongs_to :item, :class_name => 'CmItem', :foreign_key => 'cm_object_id'
  belongs_to :board, :class_name => 'CmBoard', :foreign_key => 'cm_object_id'
  belongs_to :nc, :class_name => 'CmNc', :foreign_key => 'cm_object_id'
  belongs_to :change, :class_name => 'CmChange', :foreign_key => 'cm_object_id'
  belongs_to :req, :class_name => 'CmReq', :foreign_key => 'cm_object_id'
  belongs_to :mlog, :class_name => 'CmMntLog', :foreign_key => 'cm_object_id'
  belongs_to :test, :class_name => 'CmTest', :foreign_key => 'cm_object_id'
  belongs_to :issue, :class_name => 'Issue', :foreign_key => 'issue_id' 
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  
  validates_presence_of :cm_object_id, :issue_id, :cm_object_type
  validates_uniqueness_of :issue_id, :scope => [:issue_id, :cm_object_id, :cm_object_type]

  named_scope :with_pending_actions, :include => :issue, :conditions => {'issues.open' => true}
  named_scope :boards_in_my_project, lambda { |project| {:conditions => 
        ["#{CmBoard.table_name}.project_id=? and cm_object_type=?", project, "CmBoad"]}}
  
  def to_s; description end
end
