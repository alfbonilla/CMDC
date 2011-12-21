class CmTempoReqsReq < ActiveRecord::Base
  belongs_to :parent_req, :class_name => 'CmReq', :foreign_key => 'cm_req_id'
  belongs_to :child_req, :class_name => 'CmReq', :foreign_key => 'child_req_id'
end