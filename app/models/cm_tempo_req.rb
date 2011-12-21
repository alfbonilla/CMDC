class CmTempoReq < ActiveRecord::Base
  belongs_to :req, :class_name => 'CmReq', :foreign_key => 'req_id'

  #Associations in CmReq
  belongs_to :project
  belongs_to :type, :class_name => 'CmReqsType', :foreign_key => 'type_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assignee, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :classification, :class_name => 'CmReqsClassification', :foreign_key => 'classification_id'
  belongs_to :subsystem, :class_name => 'CmSubsystem', :foreign_key => 'subsystem_id'
  belongs_to :verification_method, :class_name => 'CmTestVerificationMethod', :foreign_key => 'verification_method_id'

end