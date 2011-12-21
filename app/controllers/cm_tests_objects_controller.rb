class CmTestsObjectsController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy
  before_filter :find_test, :only => [:new]
  before_filter :find_tests_object, :only => [:edit, :destroy]

  def new
    if request.get?
      @cm_tests_object = CmTestsObject.new()
      @cm_tests_object.cm_test_id= params[:id]

      get_objects_to_add(params[:caller])
    end
    
    if request.post?
      @cm_tests_object = CmTestsObject.new(params[:cm_tests_object])
      @cm_tests_object.author = User.current
      
      if @cm_tests_object.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'show',:controller => 'cm_tests',
            :id => @cm_tests_object.cm_test_id })
      else
        flash[:notice] = "Error adding relation. Id:#{@cm_tests_object.x_id} to test id:#{@cm_tests_object.cm_test_id}"
        redirect_back_or_default({ :action => 'show',:controller => 'cm_tests', :id => @cm_tests_object.cm_test_id })
      end
    end
  end

  def edit
    if request.get?
      get_objects_to_add(params[:caller])
    end

    if request.post?
      if @cm_tests_object.update_attributes(params[:cm_tests_object])
        flash[:notice] = l(:notice_successful_update)
        redirect_to(:action => 'show',:controller => "cm_tests", :id =>@cm_tests_object.cm_test)
      else
        flash[:error] = "Edit not performed!!"
      end
    end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    if @cm_tests_object.destroy()
      redirect_to :controller => 'cm_tests', :action => 'show',
                  :project_id => @project, :id => params[:test_id]
    else
      flash[:error] = "Delete not performed!!"
    end
  end

  private
  def find_test
    @cm_test = CmTest.find(params[:id])
    @project = @cm_test.project
  end

  def find_tests_object
    @cm_tests_object = CmTestsObject.find(params[:id])
    @cm_test = CmTest.find(@cm_tests_object.cm_test)
    @project = @cm_test.project
  end

  def get_objects_to_add(caller)
    case caller
      when 'cm_tests_tes'
        @cm_tests_object.x_type= 'CmReq'
        @objects_to_add = get_all_objects(CmReq, @project)
        @verif_methods = CmTestVerificationMethod.find(:all)
      when 'cm_tests_docs'
        @cm_tests_object.x_type= 'CmDoc'
        @objects_to_add = get_all_objects(CmDoc, @project)
      when 'cm_tests_scenarios'
        @cm_tests_object.x_type= 'CmTestScenario'
        @objects_to_add = CmTestScenario.find(:all,:conditions => ['project_id=?',@project])
      end
  end
end
