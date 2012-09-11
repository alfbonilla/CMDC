class CmNcsStatusesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_ncs_status, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_ncs_statuses = CmNcsStatus.find(:all, 
      :conditions => ['project_id in(?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_ncs_status = CmNcsStatus.new
    end
    
    if request.post?
      @cm_ncs_status = CmNcsStatus.new(params[:cm_ncs_status])
      @cm_ncs_status.project = @project
      
      if @cm_ncs_status.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new non-conformance status'
      end
    end
  end

  def edit
    if request.post?
      if @cm_ncs_status.update_attributes(params[:cm_ncs_status])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_ncs_status.destroy
    rescue RuntimeError => e
      flash[:error]='NC Status not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_ncs_status
    @cm_ncs_status = CmNcsStatus.find(params[:id], :include => [:project])
    @project = @cm_ncs_status.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
