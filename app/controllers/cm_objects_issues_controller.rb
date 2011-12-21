class CmObjectsIssuesController < ApplicationController

  before_filter :find_cm_object, :only => [:new, :new_relation, :destroy, :show_existing_issues]

  accept_key_auth :edit, :destroy

  # This method is called always as a POST, and does not require any VIEW
  # The issue is created and related to the object
  def new
    if request.post?

      @data = {:cm_object_type => @cm_object_type, :cm_object => @object_to_relate,
          :cm_object_cont => params[:cm_object_cont] }

      # If action is executed from Meetings or from other object but requesting
      # the creation of the relation with the meeting
      if @cm_object_type == "CmBoard" or @relate_with_board_too
        issue_number=@board_to_relate.action_counter + 1
        issue_string=issue_number.to_s.rjust(3,'0')
        CmBoard.update(@board_to_relate.id, :action_counter => issue_number)

        # This case is for those calls where the relation
        if @relate_with_board_too
          issue_subject =  "[" + @board_to_relate.cm_board_code + "]-" +
                   issue_string + "[" + @object_to_relate.code + "]-" +
                   params[:issue_text]
        else
          issue_subject =  "[" + @board_to_relate.cm_board_code + "]-" +
                        issue_string + "-" + params[:issue_text]
        end
      else
        issue_subject =  "[" + @object_to_relate.code + "]-" + params[:issue_text]
      end

      issue_type = params[:issue_type]
      issue_project = params[:issue_project]

      i=Issue.new(:subject => issue_subject,
        :author => User.current,
        :tracker_id => params[issue_type][:name].to_i,
        :project_id => params[issue_project][:name].to_i,
        :assigned_to => User.current)
      if not i.save
        i.errors.each_full { |msg| flash[:error] = "Error creating Issue:" + msg }
        return
      end

      # create relation with object
      j=CmObjectsIssue.new(:cm_object_id => @object_to_relate.id, :issue_id => i.id,
          :created_on => Time.now, :author => User.current, :description => params[:issue_text],
          :cm_object_type => @cm_object_type )
      if not j.save
        j.errors.each_full { |msg| flash[:error] = "Error creating Relation with Issue:" + msg }
        return
      end

      # create relation with board object
      if @relate_with_board_too
        k=CmObjectsIssue.new(:cm_object_id => params[:board_id].to_i, :issue_id => i.id,
            :created_on => Time.now, :author => User.current, :cm_object_type => "CmBoard" )
        if not k.save
          k.errors.each_full { |msg| flash[:error] = "Error creating Relation Issue-Meeting:" + msg }
          return
        end

        # verify that the object related with the issue and the meeting has a direct relationship
        # with the meeting too. If not => create it!
        if @cm_object_type=="CmRid"
          relation=CmRidsObject.find(:first, :conditions =>['cm_rid_id=? and x_id=? and x_type=?',
            @cm_object_id, params[:board_id].to_i, "CmBoard"])
          if relation.nil?
            # Create relationship with Board-Rid
            j=CmRidsObject.new(:cm_rid_id => @cm_object_id, :x_id => params[:board_id].to_i,
              :x_type => "CmBoard", :rel_string => "Relation created through issue " + i.id.to_s,
              :target_version_id => @object_to_relate.implementation_release_id,
              :created_on => Time.now, :author => User.current )
            j.errors.each_full { |msg| flash[:error] = "Error creating Relation Meeting-RID:" + msg } unless j.save
          end
        end
      end
    end

#    respond_to do |format|
#      format.js do
#        render(:update) {|page|
#          page.reload }
#      end
#    end

    render :update do |page|
        page.replace_html  'issues', :partial => 'new_issue', :object => @data
        page.visual_effect :highlight, 'issues_related'
     end

  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)

      # Restore fields in form
      find_cm_object
      flash[:error] = 'Error creating in creation process: ' + e.message
  end

  def show_existing_issues
    @relation_desc = ""; @issue_selected = 0
    @issues_to_relate = Issue.find(:all, 
      :conditions => ['project_id = ?', @project.id], :order => 'id DESC')

    @data = {'issues_to_relate' => @issues_to_relate,
      'caller_cont' => params[:caller_cont], 'project' => @project,
      'type' => params[:type], 'cm_object_id' =>  @cm_object_id
      }

    render :update do |page|
        page.replace_html  'existing_issues', :partial => 'new_relation',
                                    :object => @data
        page.visual_effect :highlight, 'existing_issues'
    end
  end

  def new_relation
              
    if request.post?
      @caller_cont = params[:caller_cont]
      @cm_objects_issue = CmObjectsIssue.new
      @cm_objects_issue.cm_object_id = @cm_object_id
      @cm_objects_issue.created_on = Time.now
      @cm_objects_issue.author = User.current
      @cm_objects_issue.cm_object_type = @cm_object_type
      @cm_objects_issue.issue_id  = params[:issue_selected].to_i
      @cm_objects_issue.description = params[:relation_desc]

      #Increase action_counter
      if @cm_object_type == "CmBoard"
        CmBoard.update(@object_to_relate.id, :action_counter => @object_to_relate.action_counter + 1)
      end

      if @cm_objects_issue.save
        flash[:notice] = l(:notice_successful_create)
      else
        @issues_to_relate = Issue.find(:all,
          :conditions => ['project_id = ?', @project.id], :order => 'id DESC')
        flash[:error] = 'Error saving relation with issue'
      end
    end

    @data = {:cm_object_type => @cm_object_type, :cm_object => @object_to_relate,
        :cm_object_cont => @caller_cont }

    render :update do |page|
        page.replace_html  'issues', :partial => 'new_issue', :object => @data
        page.visual_effect :highlight, 'issues_related'
     end

  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)      

      # Restore fields in form
      find_cm_object
      @issues_to_relate = Issue.find(:all, :conditions => ['project_id = ?', @project.id], :order => 'id DESC')
      flash[:error] = 'There is a relation with Issue ' + @cm_objects_issue.issue_id.to_s + ' already created!'
  end

  def destroy
    @cm_object_id = params[:cm_object_id].to_i
    CmObjectsIssue.destroy(params[:relation_id])

    Journal.create(:journalized_id => @cm_object_id, :journalized_type => params[:type],
        :user => User.current, :notes => 'Deleted relation with ' + params[:child_id])

    @data = {:cm_object_type => @cm_object_type, :cm_object => @object_to_relate,
        :cm_object_cont => params[:cm_object_cont] }

    render :update do |page|
        page.replace_html  'issues', :partial => 'new_issue', :object => @data
        page.visual_effect :highlight, 'existing_issues'
    end
  end

  private

  def find_cm_object
    if params[:cm_object_id].nil?
      @cm_object_id = params[:cm_objects_issue][:cm_object_id]
    else
      @cm_object_id = params[:cm_object_id]
    end
    if params[:type].nil?
      @cm_object_type = params[:working_data][:cm_object_type]
    else
      @cm_object_type = params[:type]
    end

    @relate_with_board_too = (params[:board_id].blank?) ? false : true

    case @cm_object_type
    when "CmDoc"
      @object_to_relate = CmDoc.find(@cm_object_id)
    when "CmRid"
      @object_to_relate = CmRid.find(@cm_object_id)
    when "CmRisk"
      @object_to_relate = CmRisk.find(@cm_object_id)
    when "CmItem"
      @object_to_relate = CmItem.find(@cm_object_id)
    when "CmBoard"
      @object_to_relate = CmBoard.find(@cm_object_id)
    when "CmNc"
      @object_to_relate = CmNc.find(@cm_object_id)
    when "CmChange"
      @object_to_relate = CmChange.find(@cm_object_id)
    when "CmReq"
      @object_to_relate = CmReq.find(@cm_object_id)
    when "CmMntLog"
      @object_to_relate = CmMntLog.find(@cm_object_id)
    when "CmTest"
      @object_to_relate = CmTest.find(@cm_object_id)
    end

    # Get board to relate for cases where object require it!
    # Prepare @board_to_relate object to be used in the relationship
    # creation with board
    if @relate_with_board_too
      if @cm_object_type == "CmBoard"
        @board_to_relate = @object_to_relate
      else
        @board_to_relate = CmBoard.find(params[:board_id].to_i)
      end
    else
      @board_to_relate = @object_to_relate
    end

    @project = @object_to_relate.project
  end
end
