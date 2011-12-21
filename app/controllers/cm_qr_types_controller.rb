class CmQrTypesController < ApplicationController

  # QR_Types is not a multiproject model. Project is used for keeping the redmine
  # project where the user is working on, and use the permissions if needed

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_qr_type, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_qr_types = CmQrType.find(:all)
  end

  def new
    if request.get?
      @cm_qr_type = CmQrType.new
    end
    
    if request.post?
      @cm_qr_type = CmQrType.new(params[:cm_qr_type])
      
      if @cm_qr_type.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new quality record type'
      end
    end
  end

  def edit
    if request.post?
      if @cm_qr_type.update_attributes(params[:cm_qr_type])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_qr_type.destroy
    rescue RuntimeError => e
      flash[:error]='QR Type not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_qr_type
    @cm_qr_type = CmQrType.find(params[:id])
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
