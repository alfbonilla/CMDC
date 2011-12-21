class CmReqsReqsController < ApplicationController
  include CmCommonHelper

  accept_key_auth :edit, :destroy
      
  def new
    if request.get?
      @cm_req_id = params[:id]
      @intro_req = CmReq.find_by_id(@cm_req_id)

      @project_id = params[:project_id]
      @project = Project.find(@project_id)

      @new_type = params[:new_type].to_s

      @cm_reqs_req = CmReqsReq.new
      if @new_type == "father"
        @cm_reqs_req.child_req_id = @cm_req_id
      else
        # "brother" and "child" set the current req as the father of the relation
        @cm_reqs_req.cm_req_id = @cm_req_id
      end

      #Get Req able to relate based on TYPE-LEVEL conditions
      @level_allowed = params[:req_level].to_i
      @level_type = CmReqsType.find(:first,
        :conditions => ['level=? and (project_id in (?,?))', @level_allowed, 0, @project.id])
      if @level_type.blank?
        flash[:error] = 'There are no TEs for expected level: ' + @level_allowed.to_s +
                        ' customize Traceability Element Types if needed'
        redirect_to :controller => 'cm_reqs', :action => 'show', :id => @cm_req_id
        return
      end

      # Get all TEs of next level in projects hierarchy
      columns, values = prepare_get_for_projects(CmReq, @project, nil, nil)
      columns << "and type_id = ?"
      values << @level_type.id

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @reqs_to_add = CmReq.find(:all, :conditions => conditions, :order => "code ASC")
      if @reqs_to_add.blank?
        flash[:error] = 'There are no TEs to relate with type ' + @level_type.name
        redirect_to :controller => 'cm_reqs', :action => 'show', :id => @cm_req_id
        return
      end

      #Remove Reqs already related
      case @new_type
      when "brother"
        #req can act as father or child. Relation = Refers
        @cm_reqs_req.relation_type = 3
        already_related = CmReqsReq.find(:all, 
          :conditions => ['(cm_req_id=? or child_req_id=?) and relation_type=?',
            @cm_req_id, @cm_req_id, 3])
      when "child"
        #req has to be related as a father. Relation = Is satisfied by
        @cm_reqs_req.relation_type = 2
        already_related = CmReqsReq.find(:all, 
          :conditions => ['cm_req_id = ? and relation_type=?', @cm_req_id, 2])
      when "father"
        #req has to be related as a child. Relation = Is satisfied by anyway
        @cm_reqs_req.relation_type = 2
        already_related = CmReqsReq.find(:all, 
          :conditions => ['child_req_id = ? and relation_type=?', @cm_req_id, 2])
      end
      already_related.each do |to_del|
        case @new_type
        when "brother"
          if to_del.cm_req_id == @cm_reqs_req.cm_req_id
            req_to_del = CmReq.find_by_id(to_del.child_req_id)
          else
            req_to_del = CmReq.find_by_id(to_del.cm_req_id)
          end
        when "child"
          req_to_del = CmReq.find_by_id(to_del.child_req_id)
        when "father"
          req_to_del = CmReq.find_by_id(to_del.cm_req_id)
        end
        @reqs_to_add.delete(req_to_del)
      end
      #Remove own Req
      @reqs_to_add.delete(@intro_req)
      if @reqs_to_add.count == 0
        flash[:error] = 'There are no Traceability Elements to relate with type ' + @level_type.name
        redirect_to :controller => 'cm_reqs', :action => 'show', :id => @cm_req_id
        return
      end
    end
              
    if request.post?
      @cm_reqs_req = CmReqsReq.new(params[:cm_reqs_req])
      @new_type = params[:working_data][:new_type]
      @modified_req = CmReq.find_by_id(@cm_reqs_req.cm_req_id)

      @cm_reqs_req.created_on = Time.now
      @cm_reqs_req.author = User.current

      @message=""

      # Relations of "Refers" type do not means a status change
      if @cm_reqs_req.relation_type != 3
        manage_tempo_record("NEW")
      end

      # Recover working data
      @project_id = params[:working_data][:project_id]
      @project = Project.find(@project_id)
      @reqs_to_add = params[:working_data][:reqs_to_add]
      
      if @cm_reqs_req.save
        flash[:notice] = l(:notice_successful_update) + @message
      else       
        flash[:error] = 'Error saving relation between Traceability Elements' + @message
      end
      if @new_type == "father"
        redirect_to :controller => 'cm_reqs', :action => 'show', :id => @cm_reqs_req.child_req_id
      else
        redirect_to :controller => 'cm_reqs', :action => 'show', :id => @cm_reqs_req.cm_req_id
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    flash[:error] = 'There is a relation with TE ' + @cm_reqs_req.child_req_id.to_s + ' already created!'
  end

  def destroy
    @cm_reqs_id = params[:req_id].to_i
    @new_type = params[:new_type]
    @cm_reqs_req = CmReqsReq.find_by_id(params[:relation_id].to_i)
    # Treat the father of the relation
    @modified_req = CmReq.find_by_id(@cm_reqs_req.cm_req_id)
    @message = ""

    # Relations of "Refers" type do not means a status change
    if @cm_reqs_req.relation_type != 3 
      manage_tempo_record("DEL")
    end

    CmReqsReq.destroy(params[:relation_id])

    flash[:notice] = l(:notice_successful_update) + @message

    Journal.create(:journalized_id => @cm_reqs_id, :journalized_type => 'CmReq', :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + params[:child_id])

    if @new_type == "father"
      redirect_to :controller => 'cm_reqs', :action => 'show', :project_id => @project, :id => @cm_reqs_req.child_req_id
    else
      redirect_to :controller => 'cm_reqs', :action => 'show', :project_id => @project, :id => @cm_reqs_id
    end
  end


  private
  def manage_tempo_record(operation)

    continue_process=true

    temp_record=CmTempoReq.find(:first, :conditions => ["req_id=?", @modified_req.id])
    temp_rel_record=CmTempoReqsReq.find(:all,
        :conditions => ["cm_req_id=?", @modified_req.id])

    if temp_record or @modified_req.status == 1 or not temp_rel_record.empty?

      # Check if destroyed rel is recently added one or if added rel is recently deleted!
      unless temp_rel_record.empty?      
        same_record=CmTempoReqsReq.find(:first,
            :conditions => ["cm_req_id=? and child_req_id=?", @cm_reqs_req.cm_req_id,
                    @cm_reqs_req.child_req_id])
        if same_record
          #If user is restoring "manually" a proposed relation for deletion
          if operation=="NEW" and same_record.action=="DEL"
            #Recover relation data replacing new one!
            @cm_reqs_req.author_id=same_record.author_id
            @cm_reqs_req.created_on=same_record.created_on
          end

          #Delete recently added record
          same_record.destroy

          #Try to restore STABLE status
          if @modified_req.status != 1 and not temp_record and temp_rel_record.size == 1
            @modified_req.status=1
            @modified_req.save
            if @new_type == "father"
              @message=@message + " Traceability Element with higher level (" + @modified_req.code + ") restored to STABLE situation."
            else
              @message=@message + " Traceability Element restored to STABLE situation."
            end
          end
          continue_process=false
        end
      end

      if continue_process

        CmTempoReqsReq.create(:cm_req_id => @cm_reqs_req.cm_req_id,
          :child_req_id => @cm_reqs_req.child_req_id,
          :relation_type => @cm_reqs_req.relation_type,
          :description => @cm_reqs_req.description,
          :author_id => @cm_reqs_req.author_id,
          :created_on => @cm_reqs_req.created_on,
          :action => operation)
        @message=" Relation proposed as " + operation + "."

        #Change status to proposed
        if @modified_req.status == 1
          @modified_req.status=2
          @modified_req.save
          if @new_type == "father"
            @message=@message + " Traceability Element with higher level (" + @modified_req.code + ") changes from STABLE to PROPOSED."
          else
            @message=@message + " Traceability Element changes from STABLE to PROPOSED."
          end
        end
      end
    end

  end

end
