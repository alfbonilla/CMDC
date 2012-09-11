class CmRidCloseOutsController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_rid_close_out, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_rid_close_outs = CmRidCloseOut.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_rid_close_out = CmRidCloseOut.new
    end
    
    if request.post?
      @cm_rid_close_out = CmRidCloseOut.new(params[:cm_rid_close_out])
      @cm_rid_close_out.project = @project
      
      if @cm_rid_close_out.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new rid close out value'
      end
    end
  end

  def edit
    if request.post?
      if @cm_rid_close_out.update_attributes(params[:cm_rid_close_out])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_rid_close_out.destroy
    rescue RuntimeError => e
      flash[:error]='RID close out value not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_rid_close_out
    @cm_rid_close_out = CmRidCloseOut.find(params[:id], :include => [:project])
    @project = @cm_rid_close_out.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
end
