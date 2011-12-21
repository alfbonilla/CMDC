class CmSubsystemsController < ApplicationController
  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_subsystem, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
  end

  def new
    if request.get?
      @cm_subsystem = CmSubsystem.new
    end
    
    if request.post?
      @cm_subsystem = CmSubsystem.new(params[:cm_subsystem])
      @cm_subsystem.project = @project
      
      if @cm_subsystem.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new subsystem'
      end
    end
  end

  def edit
    if request.post?
      if @cm_subsystem.update_attributes(params[:cm_subsystem])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_subsystem.destroy
    rescue RuntimeError => e
      flash[:error]='Subsystem not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_subsystem
    @cm_subsystem = CmSubsystem.find(params[:id], :include => [:project])
    @project = @cm_subsystem.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end   
end
