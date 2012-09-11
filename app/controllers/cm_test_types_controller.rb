class CmTestTypesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_test_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_rss_auth :index, :new, :edit, :destroy

  def index
    @cm_test_types = CmTestType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_test_type = CmTestType.new
    end

    if request.post?
      @cm_test_type = CmTestType.new(params[:cm_test_type])
      @cm_test_type.project = @project

      if @cm_test_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new Test type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_test_type.update_attributes(params[:cm_test_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end
    end

  end

  def destroy
    begin
    @cm_test_type.destroy
    rescue RuntimeError => e
      flash[:error]='Traceability Element Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_test_type
    @cm_test_type = CmTestType.find(params[:id], :include => [:project])
    @project = @cm_test_type.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
