class CmCompaniesController < ApplicationController
  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_company, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index

  accept_rss_auth :index, :new, :edit, :destroy
      
  def index
    @cm_companies = CmCompany.find(:all)
  end

  def new
    if request.get?
      @cm_company = CmCompany.new
    end
    
    if request.post?
      @cm_company = CmCompany.new(params[:cm_company])
      # Companies are shared through the whole CMDC
      @cm_company.project_id = 0
      
      if @cm_company.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new company'
      end
    end
  end

  def edit   
    if request.post?    
      if @cm_company.update_attributes(params[:cm_company])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_company.destroy
    rescue RuntimeError => e
      flash[:error]='Company not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_company
    @cm_company = CmCompany.find(params[:id])
       
    if params[:working_data]
      @project = Project.find(params[:working_data][:project_id])
    else
      @project = Project.find(params[:project_id])          
    end    
    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end   
end
