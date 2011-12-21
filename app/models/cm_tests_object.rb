class CmTestsObject < ActiveRecord::Base
  belongs_to :cm_test, :class_name => 'CmTest', :foreign_key => 'cm_test_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :cm_req, :class_name => 'CmReq', :foreign_key => 'x_id'
  belongs_to :cm_doc, :class_name => 'CmDoc', :foreign_key => 'x_id'
  belongs_to :verification_method, :class_name => 'CmTestVerificationMethod', :foreign_key => 'rel_id'
  belongs_to :cm_test_scenario, :class_name => 'CmTestScenario', :foreign_key => 'x_id'

  OBJECT_TYPES = %w(CmReq CmTestScenario CmDoc)

  validates_presence_of :cm_test_id, :x_id, :x_type
  validates_uniqueness_of :x_id, :scope => [:x_id, :cm_test_id, :x_type]

  def to_s; id.to_s end
end
