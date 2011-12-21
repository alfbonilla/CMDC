class CmNcsNcsController < ApplicationController
  include CmCommonHelper
  
   accept_key_auth :edit, :destroy
      
  def new
    if request.get?
      @cm_nc_id = params[:id]
      @intro_nc = CmNc.find_by_id(@cm_nc_id)

      @project_id = params[:project_id]
      @project = Project.find(@project_id)

      #Get NC able to relate based on TYPE-LEVEL conditions
      @level_allowed = params[:nc_level].to_i + 1
      @next_level_type = CmNcsType.find(:first, 
        :conditions => ['level=? and project_id in (?,?)', @level_allowed, 0, @project.id])
      if @next_level_type.blank?
        flash[:error] = 'There are no NCs of expected level: ' + @level_allowed.to_s +
                        ' customize NC Types if needed'
        redirect_to :controller => 'cm_ncs', :action => 'show', :id => @cm_nc_id
        return
      end

      # Get all NCs of next level in projects hierarchy
      columns, values = prepare_get_for_projects(CmNc, @project, nil, nil)
      columns << "and type_id = ?"
      values << @next_level_type.id

      conditions = [columns]
      values.each do |value|
        conditions << value
      end
      @ncs_next_level = CmNc.find(:all, :conditions => conditions, :order => "code ASC")

      if @ncs_next_level.blank?
        flash[:error] = 'There are no NCs to relate with type ' + @next_level_type.name
        redirect_to :controller => 'cm_ncs', :action => 'show', :id => @cm_nc_id
        return
      end

      #Remove parent NC
      @ncs_next_level.delete(@intro_nc)
      if @ncs_next_level.count == 0
        flash[:error] = 'There are no NCs to relate with type ' + @next_level_type.name
        redirect_to :controller => 'cm_ncs', :action => 'show', :id => @cm_nc_id
        return
      end

      #Remove children already related
      # ---> JOIN !! @ncs_already_related = CmNc.find(:all, :conditions => { })
      @cm_ncs_nc = CmNcsNc.new
      @cm_ncs_nc.cm_nc_id = @cm_nc_id
    end
              
    if request.post?
      @cm_ncs_nc = CmNcsNc.new(params[:cm_ncs_nc])
      @child_nc = CmNc.find_by_id(@cm_ncs_nc.child_nc_id)

      @cm_ncs_nc.created_on = Time.now
      @cm_ncs_nc.author = User.current

      # Recover working data
      @project_id = params[:working_data][:project_id]
      @project = Project.find(@project_id)
      @ncs_next_level = params[:working_data][:ncs_next_level]
      
      if @cm_ncs_nc.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => 'cm_ncs', :action => 'show', :id => @cm_ncs_nc.cm_nc_id
      else      
        flash[:error] = 'Error saving relation between NC and child NC'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    flash[:error] = 'There is a relation with NC ' + @cm_ncs_nc.child_nc_id.to_s + ' already created!'
  end

  def destroy
    @cm_ncs_id = params[:nc_id].to_i
    CmNcsNc.destroy(params[:relation_id])

    Journal.create(:journalized_id => @cm_ncs_id, :journalized_type => 'CmNc', :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + params[:child_id])

    redirect_to :controller => 'cm_ncs', :action => 'show', :project_id => @project, :id => @cm_ncs_id
  end
end
