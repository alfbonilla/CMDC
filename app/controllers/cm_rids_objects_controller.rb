class CmRidsObjectsController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy    

  def new
    if request.get?
      get_item_to_relate("parms")

      prepare_combos()

      @cm_rids_object = CmRidsObject.new
      @cm_rids_object.x_id = @x_id
      @cm_rids_object.x_type = @x_type

      if @cm_rids_object.x_type == "CmBoard"
        @cm_rids_object.rel_bool = true
      end
    end
              
    if request.post? 
      @cm_rids_object = CmRidsObject.new(params[:cm_rids_object])
      @cm_rids_object.author = User.current
      @cm_rids_object.created_on = Time.now

      #Restore working_data, just in case of error
      @caller_cont = params[:working_data][:caller_cont]
      @project_id = params[:working_data][:project_id]
      @x_type = params[:working_data][:x_type]
      @project=Project.find(:first, :conditions => ["id = ?", @project_id])

      if @cm_rids_object.x_type == "CmBoard"
        # request issue creation
        if params[:working_data][:create_issue].to_i == 1
          # create issue, by default assigned to the one that created the issue
          board=CmBoard.find(@cm_rids_object.x_id)
          issue_number=board.action_counter + 1
          issue_string=issue_number.to_s.rjust(3,'0')
          CmBoard.update(board.id, :action_counter => issue_number)

          if params[:working_data][:issue_subject].blank?
            subject=""
          else
            subject="-" + params[:working_data][:issue_subject] 
          end
          
          issue_subject =  "[" + board.cm_board_code + "]-" +
                issue_string + "-[" + @cm_rids_object.cm_rid.code + "]" + subject
          i=Issue.new(:subject => issue_subject,
            :author => @cm_rids_object.author,
            :tracker_id => params[:working_data][:issue_type].to_i,
            :project_id => params[:working_data][:issue_project].to_i,
            :assigned_to => @cm_rids_object.author)
          if not i.save
            i.errors.each_full { |msg| flash[:error] = "Error creating Issue:" + msg }
            prepare_combos()
            return
          end
          
          # create relation with board
          j=CmObjectsIssue.new(:cm_object_id => @cm_rids_object.x_id, :issue_id => i.id,
              :cm_object_type => "CmBoard", :created_on => Time.now, :author => @cm_rids_object.author )
          if not j.save
            j.errors.each_full { |msg| flash[:error] = "Error creating Board-Issue:" + msg }
            prepare_combos()
            return
          end

          # create relation with rid
          k=CmObjectsIssue.new(:cm_object_id => @cm_rids_object.cm_rid_id, :issue_id => i.id,
              :cm_object_type => "CmRid", :description => "Relation created in board " + board.cm_board_code,
              :created_on => Time.now, :author => @cm_rids_object.author)
          if not k.save
            k.errors.each_full { |msg| flash[:error] = "Error creating Rid-Issue:" + msg }
            prepare_combos()
            return
          end
        end

        #RIDS treatment => update selected RID (status=Closed, close-out=selected)
        rid_modified=false
        if @cm_rids_object.rel_bool
          cm_rid=CmRid.find(:first, :conditions => ["id=?", @cm_rids_object.cm_rid_id])
          if cm_rid.nil?
            flash[:error] = "RID selected does not exist. Probably deleted during the process!"
            prepare_combos()
            return
          end
          cm_rid.init_journal(User.current, "Update from Meeting " + params[:working_data][:item_name])
          closeout=CmRidCloseOut.find(:first, :conditions => ["project_id=? and name=?",
              @project_id, @cm_rids_object.rel_string])
          cm_rid.internal_status_id=2
          cm_rid.close_out_id=closeout.id
#          CmRid.update(@cm_rids_object.cm_rid_id, :internal_status_id => 2,
#            :close_out_id => closeout.id)
          if cm_rid.save
            rid_modified=true
          else
            cm_rid.errors.add_to_base("Error updating RID " + cm_rid.code)
            flash[:error] = cm_rid.errors.full_messages.to_sentence
            prepare_combos()
            return
          end
        end
      end
         
      if @cm_rids_object.save
        if rid_modified
          flash[:notice] = l(:notice_successful_create) + " RID Closed."
        else
          flash[:notice] = l(:notice_successful_create)
        end
        
        redirect_to :controller => params[:working_data][:caller_cont],
          :action => 'show', :id => @cm_rids_object.x_id
      else
        get_item_to_relate("ownparms")
        prepare_combos()
        flash[:error] = "Error saving relation with RID"
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    get_item_to_relate("ownparms")
    prepare_combos()

    flash[:error] = 'There is a relation with RID ' + @cm_rids_object.cm_rid.code + ' already created!'
  end

  def edit
    @cm_rids_object = CmRidsObject.find(params[:id])
    get_item_to_relate("object")
    
    if request.get?
      @code = params[:code]
      prepare_combos()
    end

    if params[:cm_rids_object]
      attrs = params[:cm_rids_object].dup
      @cm_rids_object.attributes = attrs
    end

    if request.post?
      # Recover working data
      @code = params[:working_data][:rid_code]

      if @cm_rids_object.valid?
        if @cm_rids_object.save
          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update)

          Journal.create(:journalized_id => @cm_rids_object.x_id, :journalized_type => @x_type,
                :user_id => User.current.id,:notes => 'Edited relation with ' + @code)

          redirect_to :controller => @caller_cont,
                    :action => 'show', :id => @cm_rids_object.x_id
        else
          get_item_to_relate("ownparms")
          prepare_combos()
          flash[:error] = 'Error saving relation with RID'
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
    CmRidsObject.destroy(params[:relation_id])
    params[:code].nil? ? code = "Unknown" : code = params[:code]

    Journal.create(:journalized_id => @x_id, :journalized_type => @x_type, :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + code)

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
      @x_id = params[:cm_rids_object][:x_id]
      @x_type = params[:cm_rids_object][:x_type]
      @caller_cont = params[:working_data][:caller_cont]
    when "object"
      @x_id = @cm_rids_object.x_id
      @x_type = @cm_rids_object.x_type
      @caller_cont = params[:working_data][:caller_cont] if request.post?
      @caller_cont = params[:caller_cont] if request.get?
    end

    case @x_type
      when "CmBoard"
        @item_to_relate = CmBoard.find(@x_id)
        @item_name = @item_to_relate.cm_board_code
      when "CmReq"
        @item_to_relate = CmReq.find(@x_id)
        @item_name = @item_to_relate.name
    end

    @project = Project.find(@item_to_relate.project_id)
    @project_id = @project.id
  end

  def prepare_combos
    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
    @issue_types = @project.trackers.find(:all)
    @issue_projects = @project.children.visible
    @issue_projects.insert(0, @project)
    @close_out_values = CmRidCloseOut.find_all_by_project_id(@project.id)

    # Get all Changes Open in projects hierarchy
    columns, values = prepare_get_for_projects(CmRid, @project, params[:query_subp], params[:query])
    columns << " and #{CmRid.table_name}.internal_status_id != ? and #{CmRid.table_name}.internal_status_id != ? "
    values << 2
    values << 3

    conditions = [columns]
    values.each do |value|
      conditions << value
    end

    @rids = CmRid.find(:all, :conditions => conditions)
    # Old named_scope method => @rids = CmRid.open.my_project(@project.id)
  end
end
