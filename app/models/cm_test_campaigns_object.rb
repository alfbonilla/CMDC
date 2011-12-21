class CmTestCampaignsObject < ActiveRecord::Base
  belongs_to :cm_test_campaign, :class_name => 'CmTestCampaign', :foreign_key => 'cm_test_campaign_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assigned_to, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :cm_test, :class_name => 'CmTest', :foreign_key => 'cm_test_id'
  belongs_to :cm_test_scenario, :class_name => 'CmTestScenario', :foreign_key => 'cm_test_scenario_id'
  belongs_to :cm_test_record, :class_name => 'CmTestRecord', :foreign_key => 'cm_test_record_id', :dependent => :destroy
  
  
  OBJECT_TYPES = %w(CmTest)

  validates_presence_of :cm_test_campaign_id, :cm_test_id
#  validates_uniqueness_of :x_id, :scope => [:x_id, :cm_test_campaign_id, :x_type]

  def to_s; id.to_s end

  def destroy_all_children

    @current_campaigns_object = CmTestCampaignsObject.find(self.id)
    if @current_campaigns_object.cm_test_record_id != 0
      @record = CmTestRecord.find(:first,:conditions => ['id=?',@current_campaigns_object.cm_test_record_id ])
      @all_execution_records = CmTestRecord.find(:first,:conditions => ['code=?',@record.code ])

       @all_execution_records.each {|x|
        x.destroy
      }


    end
  end

end
