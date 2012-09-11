class CmTestScenariosController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_test_scenario, :only => [:show, :edit, :destroy]
  before_filter :authorize, :except => :reload_scenario_box

  accept_rss_auth :new, :edit, :destroy 

  helper :journals
  include JournalsHelper
  helper :cm_common
  include CmCommonHelper

  def index
    @cm_test_scenarios = CmTestScenario.find(:all, :conditions => ['project_id=?', @project.id])

    if @cm_test_types.nil?
      @cm_test_types = CmReqsType.find(:all, :conditions => ['project_id=?', @project.id])
      @cm_test_types.insert(0, CmTestType.new(:name => "All", :id => 0))
    end
    if @cm_test_classifications.nil?
      @cm_test_classifications = CmTestClassification.find(:all, :conditions => ['project_id=?', @project.id])
      @cm_test_classifications.insert(0, CmTestClassification.new(:name => "All", :id => 0))
    end

  end


  def new
    if request.get?
      prepare_combos()
      if params[:cm_test_scenario]
         @cm_test_scenario = CmTestScenario.new(params[:cm_test_scenario])
         @cm_test_scenario.code = ""
      else
        @cm_test_scenario = CmTestScenario.new
      end
    end

    if request.post?
      @cm_test_scenario = CmTestScenario.new(params[:cm_test_scenario])
      @cm_test_scenario.project = @project
      @cm_test_scenario.author = User.current

      prev_code = @cm_test_scenario.code
      if @cm_test_scenario.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_test_scenario.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_test_scenario.code
        end

        if params[:continue]
          redirect_to :action => 'new', :id => @project, :cm_test_scenario => params[:cm_test_scenario]
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_test_scenario })
        end
      else
        prepare_combos()
        flash[:error] = 'Error creating new Test scenario'
      end
    end
    
  end

  def edit

    prepare_combos()
    
    @notes = params[:notes]
    journal = @cm_test_scenario.init_journal(User.current, @notes)

    if params[:cm_test_scenario]
      attrs = params[:cm_test_scenario].dup
      @cm_test_scenario.attributes = attrs
    end
    
    if request.post?
      if @cm_test_scenario.save
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'show', :id => @cm_test_scenario})
      else
        flash[:error] = "Edit not performed!!"
      end
    end

  end

  def show
    prepare_combos()
    @journals = @cm_test_scenario.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  
  def destroy
    begin
    @cm_test_scenario.destroy
    rescue RuntimeError => e
      flash[:error]='Traceability Element scenario not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end


  def reload_scenario_box
    @results = CmTestsObject.find(:all,:conditions =>['cm_test_id=? and x_type=?',params[:cm_test_id],'CmTestScenario'])
    render :partial => 'options'
  end

  private


  def prepare_combos()

#      if @cm_test_scenario.type.blank?
#        @cm_test_scenario.type = CmTestType.default(@project.id)
#        unless @cm_test_scenario.type
#          render_error "The Test Elements have no Type set as default!"
#          return
#        end
#      end
#      @cm_soc_control if @cm_req.type.
#      logger.error("SCO_CONTROL:" + @cm_soc_control.to_s)
#      if @cm_test_scenario.classification.blank?
#        @cm_test_scenario.classification = CmTestClassification.default(@project.id)
#        unless @cm_test_scenario.classification
#          render_error "The Test Elements have no Classification set as default!"
#          return
#        end
#      end

      @cm_test_assignees = @project.assignable_users
      unless @cm_test_assignees
        render_error "There are no users assigned to the Project!"
        return
      end

      @cm_test_classifications = CmTestClassification.find(:all, :conditions => ['project_id=?', @project.id])
  end


  def find_cm_test_scenario
    @cm_test_scenario = CmTestScenario.find(params[:id], :include => [:project])
    @project = @cm_test_scenario.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
 
end
