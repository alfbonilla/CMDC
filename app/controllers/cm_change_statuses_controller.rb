class CmChangeStatusesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_change_status, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_change_statuses = CmChangeStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_change_status = CmChangeStatus.new
    end
    
    if request.post?
      @cm_change_status = CmChangeStatus.new(params[:cm_change_status])
      @cm_change_status.project = @project
      
      if @cm_change_status.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new change status'
      end
    end
  end

  def edit
    if request.post?
      if @cm_change_status.update_attributes(params[:cm_change_status])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_change_status.destroy
    rescue RuntimeError => e
      flash[:error]='Change Status not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_change_status
    @cm_change_status = CmChangeStatus.find(params[:id], :include => [:project])
    @project = @cm_change_status.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
end
