class CmMntLogStatusesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_mnt_log_status, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_mnt_log_statuses = CmMntLogStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_mnt_log_status = CmMntLogStatus.new
    end
    
    if request.post?
      @cm_mnt_log_status = CmMntLogStatus.new(params[:cm_mnt_log_status])
      @cm_mnt_log_status.project = @project
      
      if @cm_mnt_log_status.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new maintenance log status'
      end
    end
  end

  def edit
    if request.post?
      if @cm_mnt_log_status.update_attributes(params[:cm_mnt_log_status])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_mnt_log_status.destroy
    rescue RuntimeError => e
      flash[:error]='Mnt Log Status not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_mnt_log_status
    @cm_mnt_log_status = CmMntLogStatus.find(params[:id], :include => [:project])
    @project = @cm_mnt_log_status.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
