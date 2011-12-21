class CmSmrsAffectedFilesController < ApplicationController

  before_filter :find_cm_smrs_affected_file, :only => [:edit, :destroy]
  before_filter :find_project, :only => [:new]
  before_filter :authorize

  accept_key_auth :edit, :destroy    

  helper :journals
  include JournalsHelper

  def new
    @cm_source_files = CmSourceFile.find(:all, :conditions => { :project_id => @project.id})

    if request.get?
      @cm_smr_id = params[:cm_smr_id]
      @cm_smrs_affected_file = CmSmrsAffectedFile.new
      @cm_smrs_affected_file.cm_smr_id = @cm_smr_id
    end
              
    if request.post? 
      @cm_smrs_affected_file = CmSmrsAffectedFile.new(params[:cm_smrs_affected_file])

      #file_name edited in "working_data" prevails over the combo box
      unless params[:working_data][:file_name].blank?
        @cm_smrs_affected_file.file_name=params[:working_data][:file_name]
      end

      @cm_smr_id = params[:working_data][:cm_smr_id]
      @cm_smrs_affected_file.cm_smr_id = @cm_smr_id
      @cm_smrs_affected_file.project_id = @project.id
      @cm_smrs_affected_file.author = User.current
      @cm_smrs_affected_file.created_on = Time.now
      @cm_smrs_affected_file.updated_on = @cm_smrs_affected_file.created_on

      if @cm_smrs_affected_file.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => 'cm_smrs', :action => 'show', :id => @cm_smrs_affected_file.cm_smr_id
      else
        flash[:error] = 'Error saving implementation between SMR and Affected Item'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    flash[:error] = 'There is a relation with SMR ' + @cm_smrs_affected_file.cm_smr_id.to_s + ' already created!'
  end

  def edit
    @cm_source_files = CmSourceFile.find(:all, :conditions => { :project_id => @project.id})

    if request.post?

      #file_name edited in "working_data" prevails over the combo box
      unless params[:working_data][:file_name].blank?
        @cm_smrs_affected_file.file_name=params[:working_data][:file_name]
      end

      @cm_smrs_affected_file.updated_on = Time.now
      @cm_smrs_affected_file.author = User.current
      if @cm_smrs_affected_file.update_attributes(params[:cm_smrs_affected_file])
        flash[:notice] = l(:notice_successful_update)
     
        redirect_to :controller => 'cm_smrs', :action => 'show',
          :project_id => @project, :id => @cm_smrs_affected_file.cm_smr_id
      else
        flash[:error] = "Edit not performed!!"
      end
    end
  end

  def destroy
    @cm_smrs_affected_file.destroy

    Journal.create(:journalized_id => @cm_smrs_affected_file.cm_smr_id,
        :journalized_type => 'CmSmr', :user_id => User.current.id,
        :notes => 'Deleted relation with ' + @cm_smrs_affected_file.file_name)

    redirect_to :controller => 'cm_smrs', :action => 'show', 
      :project_id => @project, :id => @cm_smrs_affected_file.cm_smr_id
  end

  private

  def find_cm_smrs_affected_file
    @cm_smrs_affected_file = CmSmrsAffectedFile.find(params[:id], :include => [:smr, :project, :author])
    @project = @cm_smrs_affected_file.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
