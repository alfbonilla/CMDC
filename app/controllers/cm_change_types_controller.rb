class CmChangeTypesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_change_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_change_types = CmChangeType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_change_type = CmChangeType.new
    end
    
    if request.post?
      @cm_change_type = CmChangeType.new(params[:cm_change_type])
      @cm_change_type.project = @project
      
      if @cm_change_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new change type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_change_type.update_attributes(params[:cm_change_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_change_type.destroy
    rescue RuntimeError => e
      flash[:error]='Change Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_change_type
    @cm_change_type = CmChangeType.find(params[:id], :include => [:project])
    @project = @cm_change_type.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
