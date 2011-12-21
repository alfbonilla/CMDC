class CmChangesObjectsController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy    

  def new
    if request.get?
      get_item_to_relate("parms")

      prepare_combos()

      @cm_changes_object = CmChangesObject.new
      @cm_changes_object.x_id = @x_id
      @cm_changes_object.x_type = @x_type
    end

    if request.post? 
      @cm_changes_object = CmChangesObject.new(params[:cm_changes_object])
      @cm_changes_object.author = User.current
      @cm_changes_object.created_on = Time.now

      #Restore working_data, just in case of error
      @caller_cont = params[:working_data][:caller_cont]
      @project_id = params[:working_data][:project_id]

      if @cm_changes_object.x_type == "CmBoard"
        # request issue creation
        if params[:working_data][:create_issue].to_i == 1
          # create issue, by default assigned to the one that created the issue
          board=CmBoard.find(@cm_changes_object.x_id)
          issue_number=board.action_counter + 1
          issue_string=issue_number.to_s.rjust(3,'0')
          CmBoard.update(board.id, :action_counter => issue_number)

          if params[:working_data][:issue_subject].blank?
            subject=""
          else
            subject="-" + params[:working_data][:issue_subject] 
          end

          issue_subject =  "[" + board.cm_board_code + "]-" +
                issue_string + "-[" + @cm_changes_object.cm_change.code + "]" + subject

          i=Issue.new(:subject => issue_subject,
            :author => @cm_changes_object.author,
            :tracker_id => params[:working_data][:issue_type].to_i,
            :project_id => params[:working_data][:issue_project].to_i,
            :assigned_to => @cm_changes_object.author)
          if not i.save
            i.errors.each_full { |msg| flash[:error] = "Error creating Issue:" + msg }
            return
          end
          
          # create relation with board
          j=CmObjectsIssue.new(:cm_object_id => @cm_changes_object.x_id, :issue_id => i.id,
              :cm_object_type => "CmBoard",:created_on => Time.now, :author => @cm_changes_object.author )
          if not j.save
            j.errors.each_full { |msg| flash[:error] = "Error creating Board-Issue:" + msg }
            return
          end

          # create relation with change
          k=CmObjectsIssue.new(:cm_object_id => @cm_changes_object.cm_change_id, :issue_id => i.id,
              :cm_object_type => "CmChange", :description => "Relation created in board " + board.cm_board_code,
              :created_on => Time.now, :author => @cm_changes_object.author)
          if not k.save
            k.errors.each_full { |msg| flash[:error] = "Error creating Change-Issue:" + msg }
          end
        end
      end
         
      if @cm_changes_object.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => params[:working_data][:caller_cont],
          :action => 'show', :id => @cm_changes_object.x_id
      else
        get_item_to_relate("ownparms")
        prepare_combos()
        flash[:error] = 'Error saving relation with Change'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    get_item_to_relate("ownparms")
    prepare_combos()

    flash[:error] = 'There is a relation with Change ' + @cm_changes_object.cm_change.code + ' already created!'
  end

  def edit
    @cm_changes_object = CmChangesObject.find(params[:id])
    get_item_to_relate("object")
    
    if request.get?
      @change_code = params[:change_code]
      @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
    end

    if params[:cm_changes_object]
      attrs = params[:cm_changes_object].dup
      @cm_changes_object.attributes = attrs
    end

    if request.post?
      # Recover working data
      @change_code = params[:working_data][:change_code]

      if @cm_changes_object.valid?
        if @cm_changes_object.save
          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update)

          Journal.create(:journalized_id => @cm_changes_object.x_id, :journalized_type => @x_type,
                :user_id => User.current.id,:notes => 'Edited relation with ' + @change_code)

          redirect_to :controller => @caller_cont,
                    :action => 'show', :id => @cm_changes_object.x_id
        else
          get_item_to_relate("ownparms")
          @changes = CmChange.open.my_project(@project.id)
          @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
          flash[:error] = 'Error saving relation with Change'
        end
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    @x_id = params[:x_id].to_i
    @x_type = params[:x_type]
    CmChangesObject.destroy(params[:relation_id])
    params[:change_code].nil? ? change_code = "Unknown" : change_code = params[:change_code]

    Journal.create(:journalized_id => @x_id, :journalized_type => @x_type, :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + change_code)

    redirect_to :controller => params[:caller_cont], :action => 'show', :id => @x_id
  end

  private

  def get_item_to_relate(from_where)
    #Pass parms to instance vbles and recover item to relate based on x_type
    case from_where
    when "parms"
      @x_id = params[:x_id]
      @x_type = params[:x_type]
      @caller_cont = params[:caller_cont]
    when "ownparms"
      @x_id = params[:cm_changes_object][:x_id]
      @x_type = params[:cm_changes_object][:x_type]
      @caller_cont = params[:working_data][:caller_cont]
    when "object"
      @x_id = @cm_changes_object.x_id
      @x_type = @cm_changes_object.x_type
      @caller_cont = params[:working_data][:caller_cont] if request.post?
      @caller_cont = params[:caller_cont] if request.get?
    end

    case @x_type
      when "CmBoard"
        @item_to_relate = CmBoard.find(@x_id)
        @item_name = @item_to_relate.cm_board_code
      when "CmItem"
        @item_to_relate = CmItem.find(@x_id)
        @item_name = @item_to_relate.name
      when "CmDoc"
        @item_to_relate = CmDoc.find(@x_id)
        @item_name =  @item_to_relate.code
      when "CmReq"
        @item_to_relate = CmReq.find(@x_id)
        @item_name = @item_to_relate.name
    end

    @project = Project.find(@item_to_relate.project_id)
    @project_id = @project.id
  end

  def prepare_combos
    @issue_types = @project.trackers.find(:all)
    @issue_projects = @project.children.visible
    @issue_projects.insert(0, @project)
    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])

    # Get all Changes Open in projects hierarchy
    columns, values = prepare_get_for_projects(CmChange, @project, params[:query_subp], params[:query])
    columns << "and #{CmChangeStatus.table_name}.is_closed = ?"
    values << false

    conditions = [columns]
    values.each do |value|
      conditions << value
    end

    @changes = CmChange.find(:all, :conditions => conditions, :include => :status)
    #Old named_scope method => @changes = CmChange.open.my_project(@project.id)
  end
end
