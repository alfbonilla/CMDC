class CmChangesChangesController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy    
 
  def new
    if request.get?
      @project_id = params[:project_id]
      @project = Project.find(@project_id)

      @rest_of_changes = get_all_objects(CmChange, @project)

      @cm_changes_change = CmChangesChange.new
      @change_id = params[:id]
      @cm_changes_change.parent_change_id = @change_id
      @change_to_relate = CmChange.find_by_id(@change_id)
      @rest_of_changes.delete(@change_to_relate)
    end
              
    if request.post?
      @cm_changes_change = CmChangesChange.new(params[:cm_changes_change])
      @cm_changes_change.author = User.current
      @cm_changes_change.created_on = Time.now
      
      # Recover working data
      @project = Project.find(params[:working_data][:project_id])

      if @cm_changes_change.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => 'cm_changes', :action => 'show', :project_id => @project_id,
          :id => @cm_changes_change.parent_change_id
      else
        flash[:error] = 'Error saving relation between change and child change'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)

      # Restore fields in form
      @change_id = params[:id]
      @change_to_relate = CmChange.find_by_id(@change_id)
      @rest_of_changes = get_all_objects(CmChange, @project)
      @rest_of_changes.delete(@change_to_relate)

      flash[:error] = 'There is a relation with Change ' + @cm_changes_change.child_change_id.to_s
                  + ' already created!'
  end

  def destroy
    @change_id = params[:change_id].to_i
    CmChangesChange.destroy(params[:relation_id])

    Journal.create(:journalized_id => @change_id, :journalized_type => 'CmChange', :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + params[:child_id])

    redirect_to :controller => 'cm_changes', :action => 'show', :project_id => @project, :id => @change_id
  end
  
end
