class CmTestCampaignsObjectsController < ApplicationController
  before_filter :find_cm_test_campaigns_object, :only => [:edit, :destroy]
  accept_rss_auth :edit, :destroy

  include CmCommonHelper
  helper :sort
  include SortHelper

  def new
    if request.get?
      prepare_combos()
      @cm_test_campaign_id = params[:id]
      @cm_test_campaign = CmTestCampaign.find(:first, :conditions => ['id=?', @cm_test_campaign_id])
      @number_of_test_related = (params[:number_of_tests].to_i + 1) * 10
    end

    if request.post?

        @cm_test = CmTest.find(:first, :conditions => ['id=?',params[:cm_test_campaigns_object][:cm_test_id] ])
        @cm_test_campaigns_object = CmTestCampaignsObject.new(params[:cm_test_campaigns_object])
        @cm_test_campaigns_object.author_id = User.current
        @cm_test_campaigns_object.created_on = Time.now

        #If test has at least a related scenario
        if params[:cm_test_campaigns_object][:cm_test_scenario_id] and (params[:cm_test_campaigns_object][:cm_test_scenario_id] != '0')
           if @cm_test_campaigns_object.save
              flash[:notice] = l(:notice_successful_create)
              redirect_to :controller => 'cm_test_campaigns', :action => 'show', :project_id => @project_id,
                          :id => params[:id]
           else
              flash[:error] = 'Error saving relation between Test Campaign and Test'
              redirect_to :controller => 'cm_test_campaigns', :action => 'show', :project_id => @project_id,
                              :id => params[:id]
            end
        else
            flash[:error] = 'Before to relation a test to campaign, it is necessary add at least one scenario to that test'
            redirect_to :controller => 'cm_test_campaigns', :action => 'show', :project_id => @project_id,
                              :id => params[:id]
        end
    end

  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)

      # Restore fields in form
      @itest_campaign_id = params[:id]
      @test_campaign_to_relate = CmTest.find_by_id(@itest_campaign_id)
      @rest_of_test_campaigns = CmTest.find(:all, :conditions => ['project_id=?', @project.id])
      @rest_of_test_campaigns.delete(@test_campaign_to_relate)

      flash[:error] = 'There is a relation with Test ' + @cm_test.id + ' already created!'
  end

  def edit

    if request.get?
       prepare_combos()
    end

    if request.post?
      
      if params[:cm_test_campaigns_object]
        attrs = params[:cm_test_campaigns_object].dup
#        @old_cm_test_object = CmTestsObject.find(:first,:conditions =>
#                ["cm_test_id=? and x_id=? and x_type=?",@cm_test_campaigns_object.cm_test_id,@cm_test_campaigns_object.cm_test_scenario_id,'CmTestScenario'])
        @cm_test_campaigns_object.attributes = attrs
      end

      if @cm_test_campaigns_object.valid?
         call_hook(:controller_cm_test_campaigns_object_edit_before_save, { :params => params, :cm_test_campaigns_object => @cm_test_campaigns_object})
         if @cm_test_campaigns_object.save         

               flash[:notice] = l(:notice_successful_update)
               call_hook(:controller_cm_test_campaigns_object_edit_after_save, { :params => params, :cm_test_campaigns_object => @cm_test_campaigns_object})
               redirect_to(:action => 'show',:controller => "cm_test_campaigns", :id =>@cm_test_campaigns_object.cm_test_campaign_id)
          else
            flash[:error] = 'Error saving relation with Test'
         end
      end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    @cm_test_id = params[:cm_test_id].to_i
    
    CmTestCampaignsObject.destroy(params[:id])
    if @caller_cont == "cm_test_campaigns"
      redirect_id = @cm_test_campaigns_object.cm_test_campaign_id
    else
      redirect_id = params[:cm_test_campaign_id]
    end
    
    redirect_to :controller => params[:caller_cont], :action => 'show', :id => redirect_id
  end

  private

  def prepare_combos
    @project = Project.find(params[:project_id])
    @rest_of_tests = get_all_objects(CmTest, @project)
    #@rest_of_scenarios only load scenarios for the first test showed in the combo box, the scenarios for the rest of tests are
    #loaded by Ajax depends on the test selected.
    @rest_of_scenarios = CmTestsObject.find(:all,:conditions =>['cm_test_id=? and x_type=?',@rest_of_tests.first.id,'CmTestScenario'])
#    @rest_of_scenarios = CmTestsObject.find(:all,:conditions =>['cm_test_id=? and x_type=?',@rest_of_tests.first.id,'CmTestScenario'],
#      :joins => 'LEFT JOIN cm_test_scenarios ON cm_tests_objects.x_id=cm_test_scenarios.id',
#      :select => 'cm_tests_objects.id,cm_test_scenarios.code,cm_test_scenarios.name,cm_tests_objects.x_id')
    @cm_test_record_assignees = @project.assignable_users
    unless @cm_test_record_assignees
      render_error "There are no users assigned to the Project!"
      return
    end
  end

  def find_cm_test_campaigns_object
  @cm_test_campaigns_object = CmTestCampaignsObject.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
 end
