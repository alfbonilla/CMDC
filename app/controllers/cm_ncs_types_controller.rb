class CmNcsTypesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_ncs_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_ncs_types = CmNcsType.find(:all, 
      :conditions => ['project_id in(?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_ncs_type = CmNcsType.new
    end
    
    if request.post?
      @cm_ncs_type = CmNcsType.new(params[:cm_ncs_type])
      @cm_ncs_type.project = @project
      
      if @cm_ncs_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new non-conformance type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_ncs_type.update_attributes(params[:cm_ncs_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_ncs_type.destroy
    rescue RuntimeError => e
      flash[:error]='NC Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_ncs_type
    @cm_ncs_type = CmNcsType.find(params[:id], :include => [:project])
    @project = @cm_ncs_type.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
