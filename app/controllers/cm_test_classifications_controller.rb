class CmTestClassificationsController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_test_classification, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_rss_auth :index, :new, :edit, :destroy

  def index
    @cm_test_classifications = CmTestClassification.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end


  def new
    if request.get?
      @cm_test_classification = CmTestClassification.new
    end
    
    if request.post?
      @cm_test_classification = CmTestClassification.new(params[:cm_test_classification])
      @cm_test_classification.project = @project

      if @cm_test_classification.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new Traceability Element classification'
      end
    end
  end

  def edit
    if request.post?
      if @cm_test_classification.update_attributes(params[:cm_test_classification])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end
    end

  end

  def destroy
    begin
    @cm_test_classification.destroy
    rescue RuntimeError => e
      flash[:error]='Traceability Element classification not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_test_classification
    @cm_test_classification = CmTestClassification.find(params[:id], :include => [:project])
    @project = @cm_test_classification.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
