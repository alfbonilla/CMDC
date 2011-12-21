class CmRiskTypesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_risk_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_risk_types = CmRiskType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_risk_type = CmRiskType.new
    end
    
    if request.post?
      @cm_risk_type = CmRiskType.new(params[:cm_risk_type])
      @cm_risk_type.project = @project
      
      if @cm_risk_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new risk type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_risk_type.update_attributes(params[:cm_risk_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_risk_type.destroy
    rescue RuntimeError => e
      flash[:error]='Risk Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_risk_type
    @cm_risk_type = CmRiskType.find(params[:id], :include => [:project])
    @project = @cm_risk_type.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
