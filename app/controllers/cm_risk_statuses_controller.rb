class CmRiskStatusesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_risk_status, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_risk_statuses = CmRiskStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_risk_status = CmRiskStatus.new
    end
    
    if request.post?
      @cm_risk_status = CmRiskStatus.new(params[:cm_risk_status])
      @cm_risk_status.project = @project
      
      if @cm_risk_status.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new risk status'
      end
    end
  end

  def edit
    if request.post?
      if @cm_risk_status.update_attributes(params[:cm_risk_status])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_risk_status.destroy
    rescue RuntimeError => e
      flash[:error]='Risk Status not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_risk_status
    @cm_risk_status = CmRiskStatus.find(params[:id], :include => [:project])
    @project = @cm_risk_status.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
