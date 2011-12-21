class CmReqsReq < ActiveRecord::Base
  belongs_to :parent_req, :class_name => 'CmReq', :foreign_key => 'cm_req_id'
  belongs_to :child_req, :class_name => 'CmReq', :foreign_key => 'child_req_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  
  validates_presence_of :cm_req_id, :child_req_id
  validates_uniqueness_of :child_req_id, :scope => [:child_req_id, :cm_req_id]
  validate :no_with_itself

  def no_with_itself
    if self.child_req_id == self.cm_req_id
      errors.add(:child_req_id, "can't be the same than origin")
    end
  end

  def to_s; description end
end
