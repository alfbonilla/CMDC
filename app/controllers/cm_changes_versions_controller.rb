class CmChangesVersionsController < ApplicationController

  accept_key_auth :new, :edit, :destroy
      
  def index
    @cm_changes_versions = CmChangesVersion.find(:all, :conditions => ['project_id=?', @project.id])
  end

  def new
    if request.get?
      @project = Project.find(params[:id])
      @project_id = @project.id
      @cm_changes_version = CmChangesVersion.new
      @cm_changes_version.cm_change_id = params[:change_id]
      
      @change_to_relate = CmChange.find(@cm_changes_version.cm_change_id)
    end   

    if request.post?
      @cm_changes_version = CmChangesVersion.new(params[:cm_changes_version])

      @project = Project.find(params[:working_data][:project_id])

      @cm_changes_version.author = User.current
      @cm_changes_version.updated_on = Time.now
      
      if @cm_changes_version.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :controller => 'cm_changes', :action => 'show',
            :id => @cm_changes_version.cm_change_id})
      else
        @change_to_relate = CmChange.find(@cm_changes_version.cm_change_id)
        @project_id = @project.id
        
        flash[:error] = 'Error creating new version for change'
      end
    end
  end

  def edit
    if request.get?
      @cm_changes_version = CmChangesVersion.find(params[:id])
      @project = Project.find(params[:project_id])
      @project_id = @project.id
      @change_to_relate = CmChange.find(@cm_changes_version.cm_change_id)
    end
    
    if request.post?
      @cm_changes_version = CmChangesVersion.find(params[:id])
      
      @cm_changes_version.author = User.current
      @cm_changes_version.updated_on = Time.now

      @project = Project.find(params[:working_data][:project_id])

      if @cm_changes_version.update_attributes(params[:cm_changes_version])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({ :controller => 'cm_changes', :action => 'show',
            :id => @cm_changes_version.cm_change_id})
      else
        @change_to_relate = CmChange.find(@cm_changes_version.cm_change_id)
        @project_id = @project.id

        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
      @cm_changes_version = CmChangesVersion.find(params[:id])
      @cm_changes_version.destroy

    rescue RuntimeError => e
      flash[:error]='Change Version not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :controller => 'cm_changes', :action => 'show',
            :id => @cm_changes_version.cm_change_id})
    end
  end
   
end
