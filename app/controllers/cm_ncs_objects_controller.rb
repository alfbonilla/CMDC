class CmNcsObjectsController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy    

  def new
    if request.get?
      
      get_item_to_relate("parms")

      prepare_combos()

      # When called from own NC, @x_id has the NC id and the cm_nc_id coming from
      # new form has the object id
      @cm_ncs_object = CmNcsObject.new
      @cm_ncs_object.x_id = @x_id
      @cm_ncs_object.x_type = @x_type
    end
              
    if request.post?
      #Restore working_data, just in case of error
      @caller_cont = params[:working_data][:caller_cont]
      @project_id = params[:working_data][:project_id]

      @cm_ncs_object = CmNcsObject.new(params[:cm_ncs_object])

      # When called from NC, change x_id and cm_nc_id
      if @caller_cont=="cm_ncs"
        aux=@cm_ncs_object.x_id
        @cm_ncs_object.x_id=@cm_ncs_object.cm_nc_id
        @cm_ncs_object.cm_nc_id=aux
        @caller_id=@cm_ncs_object.cm_nc_id
      else
        @caller_id=@cm_ncs_object.x_id
      end

      @cm_ncs_object.author = User.current
      @cm_ncs_object.created_on = Time.now

      if @cm_ncs_object.x_type == "CmBoard"
        # request issue creation
        if params[:working_data][:create_issue].to_i == 1
          # create issue, by default assigned to the one that created the issue
          board=CmBoard.find(@cm_ncs_object.x_id)
          issue_number=board.action_counter + 1
          issue_string=issue_number.to_s.rjust(3,'0')
          CmBoard.update(board.id, :action_counter => issue_number)

          if params[:working_data][:issue_subject].blank?
            subject=""
          else
            subject="-" + params[:working_data][:issue_subject]
          end

          issue_subject =  "[" + board.cm_board_code + "]-" +
                issue_string + "-[" + @cm_ncs_object.cm_nc.code + "]" + subject
          i=Issue.new(:subject => issue_subject,
            :author => @cm_ncs_object.author,
            :tracker_id => params[:working_data][:issue_type].to_i,
            :project_id => params[:working_data][:issue_project].to_i,
            :assigned_to => @cm_ncs_object.author)
          if not i.save
            i.errors.each_full { |msg| flash[:error] = "Error creating Issue:" + msg }
            return
          end
          
          # create relation with board
          j=CmObjectsIssue.new(:cm_object_id => @cm_ncs_object.x_id, :issue_id => i.id,
              :cm_object_type => "CmBoard", :created_on => Time.now, :author => @cm_ncs_object.author )
          if not j.save
            j.errors.each_full { |msg| flash[:error] = "Error creating Board-Issue:" + msg }
            return
          end

          # create relation with nc
          k=CmObjectsIssue.new(:cm_object_id => @cm_ncs_object.cm_nc_id, :issue_id => i.id,
              :cm_object_type => "CmNc", :description => "Relation created in board " + board.cm_board_code,
              :created_on => Time.now, :author => @cm_ncs_object.author)
          if not k.save
            k.errors.each_full { |msg| flash[:error] = "Error creating Nc-Issue:" + msg }
          end
        end
      end

      # Update expected release in the NCs
      CmNc.update(@cm_ncs_object.cm_nc_id, :rlse_expected_id => @cm_ncs_object.target_version_id)

      if @cm_ncs_object.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => @caller_cont, :action => 'show', :id => @caller_id
      else
        flash[:error] = 'Error creating relation'
        redirect_to :controller => @caller_cont, :action => 'show', :id => @caller_id
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)
    flash[:error] = 'There is a relation with NC ' + @cm_ncs_object.cm_nc.code + ' already created!'
    redirect_to :controller => @caller_cont, :action => 'show', :id => @caller_id
  end

  def edit
    @cm_ncs_object = CmNcsObject.find(params[:id])

    #if ! params[:caller_cont] = 'cm_test_records'
      get_item_to_relate("object")
    #end
    
    
    if request.get?
      @code = params[:code]
      @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
    end

    if params[:cm_ncs_object]
      attrs = params[:cm_ncs_object].dup
      @cm_ncs_object.attributes = attrs
    end

    if request.post?
      # Recover working data
      @code = params[:working_data][:code]

      if @cm_ncs_object.valid?
        if @cm_ncs_object.save
          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update)

          Journal.create(:journalized_id => @x_id, :journalized_type => @x_type,
                :user_id => User.current.id,:notes => 'Edited relation with ' + @code)

          redirect_to :controller => @caller_cont, :action => 'show', :id => @x_id
        else
          flash[:error] = 'Error saving relation!'
          redirect_to :controller => @caller_cont, :action => 'show', :id => @x_id
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
    CmNcsObject.destroy(params[:relation_id])
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
    when "object"
      @caller_cont = params[:working_data][:caller_cont] if request.post?
      @caller_cont = params[:caller_cont] if request.get?
      if @caller_cont == "cm_ncs"
        @x_id = @cm_ncs_object.cm_nc_id
        @x_type = "CmNc"
      else
        @x_id = @cm_ncs_object.x_id
        @x_type = @cm_ncs_object.x_type
      end
    end

    #When the relation is created from the own NC, caller_cont parm is received
    if @caller_cont == "cm_ncs"
      @item_to_relate = CmNc.find(@x_id)
      @item_name = @item_to_relate.code
    else
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
        when "CmTestRecord"
          @item_to_relate = CmTestRecord.find(@x_id)
          @item_name = @item_to_relate.code
      end
    end

    @project = Project.find(@item_to_relate.project_id)
    @project_id = @project.id
  end

  def prepare_combos
    @issue_types = @project.trackers.find(:all)
    @issue_projects = @project.children.visible
    @issue_projects.insert(0, @project)

    # When relation is created from own NC, x_type says which list to get
    case @caller_cont
    when "cm_ncs"
      case @x_type
      when "CmItem"
        @items_to_select = get_all_objects(CmItem, @project)
      when "CmReq"
        @items_to_select = get_all_objects(CmReq, @project)
      end
    else
      # Get all NCs in projects hierarchy
      columns, values = prepare_get_for_projects(CmNc, @project, params[:query_subp], params[:query])

      if @caller_cont == "cm_test_records"
        # Filter those ready to verify
        columns << "and #{CmNcsStatus.table_name}.is_ready_to_verify = ?"
        values << true
      else
        # Filter those not closed
        columns << "and #{CmNcsStatus.table_name}.is_closed = ?"
        values << false
      end
      conditions = [columns]
      values.each do |value|
        conditions << value
      end
      @items_to_select = CmNc.find(:all, :conditions => conditions, :include => :status)
    end

    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
  end
end
