class CmMntLogTypesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_mnt_log_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_mnt_log_types = CmMntLogType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_mnt_log_type = CmMntLogType.new
    end
    
    if request.post?
      @cm_mnt_log_type = CmMntLogType.new(params[:cm_mnt_log_type])
      @cm_mnt_log_type.project = @project
      
      if @cm_mnt_log_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new maintenance log type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_mnt_log_type.update_attributes(params[:cm_mnt_log_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_mnt_log_type.destroy
    rescue RuntimeError => e
      flash[:error]='Mnt Log Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_mnt_log_type
    @cm_mnt_log_type = CmMntLogType.find(params[:id], :include => [:project])
    @project = @cm_mnt_log_type.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end    
end
