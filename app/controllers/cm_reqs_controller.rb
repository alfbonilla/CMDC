class CmReqsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_req, :only => [:show, :edit, :destroy, :new_issue, :approve,
      :reject, :dismiss, :change_log, :propose]
  before_filter :find_project, :only => [:new, :index, :index_tree, :approve_all, 
      :matrix, :import_trace]
  before_filter :authorize, :except => [:change_log, :type_modified]

  accept_key_auth :show, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :attachments
  include AttachmentsHelper
  helper :sort
  include SortHelper
  helper :watchers
  include WatchersHelper
  helper :cm_reqs_reqs
  include CmReqsReqsHelper
  helper :cm_reqs
  include CmReqsHelper
  helper :cm_rids
  include CmRidsHelper
  helper :cm_common
  include CmCommonHelper
  include CmImportAssistant

  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }
           
  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init [['type_id', 'asc'] , ['display_order', 'asc']]
    sort_update %w(id code name assigned_to_id type_id)

    @date_created=nil

    #define filter capabilities
    conditions=prepare_filter()

    if @cm_req_types.nil?
      @cm_req_types = CmReqsType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_req_types.insert(0, CmReqsType.new(:name => "All", :id => 0))
    end
    if @cm_req_classifications.nil?
      @cm_req_classifications = CmReqsClassification.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_req_classifications.insert(0, CmReqsClassification.new(:name => "All", :id => 0))
    end
    if @cm_subsystems.nil?
      @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
      @cm_subsystems.insert(0,CmSubsystem.new(:name => "All", :id=> 0))
    end
    @cm_req_statuses = {'All' => 0, change_t_status_to_s(1) => 1,
      change_t_status_to_s(2) => 2, change_t_status_to_s(3) => 3} if @cm_req_statuses.nil?
    @cm_req_socs = {'All' => 0, 'Compliant' => 1, 'Compliant with Assumptions' => 2,
      'Partially Compliant' => 3, 'No Compliant' => 4} if @cm_req_socs.nil?
      
    #Get assignable users and add All and Not Assigned options
    req_assignees = @project.assignable_users
    tmp_req_assignees = {"Not Assigned" => -1}
    req_assignees.each do |assignee|
      tmp_req_assignees[assignee.name] = assignee.id
    end
    tmp_req_assignees["All"] = 0
    @cm_req_assignees=tmp_req_assignees.sort_by { |k,v| v }

    @total = CmReq.count(:conditions => conditions)

    @cm_req_pages, @cm_reqs = paginate :cm_reqs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:assignee, :type, :classification, :subsystem]

    respond_to do |format|
      format.html { render(:template => 'cm_reqs/index.rhtml', :layout => !request.xhr?) }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_req_index_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_reqs/index_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-TEsList.html")
      }
    end
  end

  def index_tree
    @cm_reqs = CmReq.find(:all, :conditions => ["project_id = ?", @project.id],
          :include => [:cm_reqs_reqs], :order => 'type_id')

    #Prepare list
    @cm_info_reqs = []
    @cm_reqs.each do |req|

      @cm_info = CmReq.new

      #cm_req fields are used for managing the new list, replacing original info (not shown in the list)
      #with special values neccessary for seeing the structure as a tree:
      #   - verification_method USED FOR indicating if the req has children
      #   - classification_id   USED FOR saving the parent req id
      #   - display_order       USED FOR saving the indentation value
      #If id is not already included
      if( !(@cm_info_reqs.detect {|pid| pid.id == req.id }))
        @cm_info.id=req.id; @cm_info.code=req.code; @cm_info.name=req.name;
        @cm_info.type_id=req.type_id; @cm_info.status=req.status
        @cm_info.classification_id=0; @cm_info.display_order=0

        related_reqs=CmReqsReq.find(:all,
          :conditions => ['cm_req_id = ? and relation_type != ?',req.id, 3])
       if related_reqs.any?
          @cm_info.verification_method_id = 1
          @cm_info_reqs << @cm_info
          get_children(req, @cm_info_reqs, 0, related_reqs)
        else
          @cm_info.verification_method_id = 0
          @cm_info_reqs << @cm_info
        end
      end
    end

    @total = @cm_reqs.count

    if request.xml_http_request?
      render(:template => 'cm_reqs/index_tree.rhtml', :layout => !request.xhr?)
    end
  end
  
  def show
    prepare_combos()
  
    min_level = CmReqsType.connection.select_value("select min(level) from cm_reqs_types where project_id=" +
        @project.id.to_s + " or project_id=0")
    if min_level.to_i < @cm_req.type.level
      @allow_relate_parent = true
    else
      @allow_relate_parent = false
    end

    max_level = CmReqsType.connection.select_value("select max(level) from cm_reqs_types where project_id=" +
        @project.id.to_s + " or project_id=0")
    if max_level.to_i > @cm_req.type.level
      @allow_relate_children = true
    else
      @allow_relate_children = false
    end

    if CmReq.find(:all, :conditions => ['id != ? and type_id = ?', @cm_req.id, @cm_req.type_id]).empty?
      @allow_relate_brother = false
    else
      @allow_relate_brother = true
    end

    @journals = @cm_req.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_reqs/show.rhtml' }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_req_show_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_reqs/show_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-TE#{@cm_req.id}.html") }
    end
  end

  def edit
    if request.get?
      prepare_combos()
    end

    @notes = params[:notes]
    journal = @cm_req.init_journal(User.current, @notes)
     
    if params[:cm_req]
      attrs = params[:cm_req].dup
      @cm_req.attributes = attrs
    end
 
    if request.post?
      if @cm_req.valid?
        call_hook(:controller_cm_req_edit_before_save, {:params => params,
                  :cm_req => @cm_req, :journal => journal})
        if @cm_req.save
          attachments = Attachment.attach_files(@cm_req, params[:attachments])
          render_attachment_warning_if_needed(@cm_req)

          if !journal.new_record?
            # Only send notification if something was actually changed
            # flash[:notice] = l(:notice_successful_update)
            @cm_req.errors.add_to_base(l(:notice_successful_update))
            flash[:notice] = @cm_req.errors.full_messages.to_sentence

            # Deliver email
            Mailer.deliver_cmdc_info(User.current, @project, @cm_req, 'cm_reqs')
          end
          call_hook(:controller_cm_req_edit_after_save, { :params => params,
                    :cm_req => @cm_req, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_req})
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash.now[:error] = l(:notice_locking_conflict)
    # Remove the previously added attachments if issue was not updated
    attachments.each(&:destroy)
  end
  
  def new 
    if request.get?
      if params[:cm_req]
        @cm_req = CmReq.new(params[:cm_req])
        @cm_req.code = ""
        @cm_req.project = @project
      else
        @cm_req = CmReq.new(:project => @project)
      end
      @cm_req.author = User.current

      prepare_combos()
    end
      
    if request.post?
      @cm_req = CmReq.new(params[:cm_req])
      @cm_req.author = User.current
      @cm_req.project = @project

      prev_code = @cm_req.code
      @cm_req.counter_type=params[:counter_type].to_i
      
      @cm_req.watcher_user_ids=params[:cm_req]['watcher_user_ids']

      if @cm_req.save
        #When coming from Req father, create the relation at the same time
        #First save, to get the new id for the child Req
        @father_id=params[:working_data][:father_id]
        unless @father_id.blank?
          #Create relationship
          CmReqsReq.create(:cm_req_id => @father_id.to_i, :child_req_id => @cm_req.id,
            :created_on => Time.now, :author => User.current, :description => " ",
            :relation_type => 2)
        end

        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_req.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_req.code
        end
        
        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_req, 'cm_reqs')

        Attachment.attach_files(@cm_req, params[:attachments])
        render_attachment_warning_if_needed(@cm_req)
        
        unless @father_id.blank?
          redirect_to :controller => 'cm_reqs', :action => 'show', :id => @father_id.to_s
        else
          if params[:continue]
            redirect_to :action => 'new', :id => @project, :cm_req => params[:cm_req]
          else
            redirect_back_or_default({ :action => 'show', :id => @cm_req })
          end
        end
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error saving Traceability Element'
      end              
    end   
  end

  def destroy
    # Check if the delete can be performed or just is proposed
    unless managed_tempo_record()
      begin
        @cm_req.destroy
      rescue RuntimeError => e
        flash[:error]='Traceability Element not deleted: ' + e.message
      ensure
        redirect_to :action => 'index', :id => @project
      end
    else
      redirect_to :action => 'show', :id => @cm_req
    end
  end

  def approve
    @message=""

    @cm_req.init_journal(User.current, "CM/DC-NotSave")

    do_approval_process
    
    if @cm_req.save
      flash[:notice]='Traceability Element approved. ' + @message
    else
      flash[:error]='Error approving Traceability Element!!'
    end
    redirect_to :action => 'show', :id => @cm_req.id
  end

  def approve_all

    if request.post?

      conta_ok=0
      conta_error=0
      @errors_found=""

      @version_new=params[:version_new]
      @version_modified=params[:version_modified]

      reqs=CmReq.find(:all, :conditions => ["project_id=? and code LIKE ? and (status = ? or status IS NULL)",
        @project, params[:codes_to_approve], 2])

      reqs.each do |@cm_req|
        @cm_req.init_journal(User.current)
        do_approval_process

        if @cm_req.save
          conta_ok+=1
        else
          conta_error+=1
          @errors_found=@errors_found + @cm_req.code + "-"
        end
      end

      if conta_error==0
        if reqs.size==0
          flash[:notice]='No Traceability Elements found to approve'
        else
          flash[:notice]='All Traceability Elements (' + conta_ok.to_s + ') approved. '
        end
      else
        flash[:error]='Not all Traceability Elements approved. Approved Ok => ' + conta_ok.to_s +
          '. Approved with Error =>' + conta_error.to_s + ' (' + @errors_found + ')'
      end
      redirect_to :action => 'index', :id => @project
    end

  end

  def dismiss

    prev_status=@cm_req.status
    case prev_status
    when 1
      #In this status, there are no Tempos
      txt="[Dismissed from STABLE] "
    when 2
      #Proposed could have Tempos
      txt="[Dismissed from PROPOSED] "
    end

    @cm_req.init_journal(User.current, txt)

    @cm_req.status=3
    if @cm_req.save

      if prev_status==2
        #Proposed could have Tempos
        CmTempoReq.delete(@cm_req.id)
        CmTempoReqsReq.delete_all(:cm_req_id => @cm_req.id)
      end

      flash[:notice]='Traceability Element dismissed. '
    else
      flash[:error]='Error dismissing Traceability Element!!'
    end
    redirect_to :action => 'show', :id => @cm_req.id

  end

  def propose

    @cm_req.init_journal(User.current, "[Proposed from DISMISSED]")

    @cm_req.status=2
    if @cm_req.save
      flash[:notice]='Traceability Element changed from DISMISSED to PROPOSED. '
    else
      flash[:error]='Error proposing Traceability Element!!'
    end
    redirect_to :action => 'show', :id => @cm_req.id
  end

  def reject
    restored=false
    message=""
    temp_record=CmTempoReq.find(:first, :conditions => ["req_id=?", @cm_req.id])

    unless temp_record.nil?
      #Restore values saved in Tempo table
      prev_action=temp_record.action

      #With this notes, the model will not save a new temp_record for the Traceability Element
      @cm_req.init_journal(User.current, "CM/DC-NotSave")

      @cm_req.code = temp_record.code
      @cm_req.name = temp_record.name
      @cm_req.description = temp_record.description
      @cm_req.version = temp_record.version
      @cm_req.type_id = temp_record.type_id
      @cm_req.classification_id = temp_record.classification_id
      @cm_req.subsystem_id = temp_record.subsystem_id
      @cm_req.verification_method_id = temp_record.verification_method_id
      @cm_req.no_ascendants = temp_record.no_ascendants
      @cm_req.no_descendants = temp_record.no_descendants
      @cm_req.optional = temp_record.optional
      @cm_req.status = 1
#Non-considered fields are not restored
#      @cm_req.assigned_to_id = temp_record.assigned_to_id
#      @cm_req.display_order = temp_record.display_order
#      @cm_req.place_in_doc = temp_record.place_in_doc
#      @cm_req.comments = temp_record.comments
      @cm_req.project_id = temp_record.project_id
      @cm_req.author_id = temp_record.author_id
      @cm_req.created_on = temp_record.created_on
      @cm_req.updated_on = temp_record.updated_on

      if @cm_req.save
        temp_record.destroy

        if prev_action=="EDIT"
          message="Traceability Element attributes restored to last STABLE situation. "
        else
          message="Traceability Element attributes restored from delete to last STABLE situation. "
        end

        restored=true
      else
        flash[:error]='Error recovering Traceability Element from last STABLE situation!!'
      end     
    end

    temp_records=CmTempoReqsReq.find(:all, :conditions => ["cm_req_id=?", @cm_req.id])
    unless temp_records.empty?
      temp_records.each do |tmp|
        if tmp.action=="NEW"
          #Delete created new relationship
          rel_to_del=CmReqsReq.find(:first,
            :conditions => ["cm_req_id=? and child_req_id=?", tmp.cm_req_id, tmp.child_req_id])
          rel_to_del.destroy unless rel_to_del.nil?
        else
          #Restore deleted relationship
          CmReqsReq.create(:cm_req_id => tmp.cm_req_id,
                           :child_req_id => tmp.child_req_id,
                           :relation_type => tmp.relation_type,
                           :description => tmp.description,
                           :author_id => tmp.author_id,
                           :created_on => tmp.created_on)
        end

        tmp.destroy
      end

      #set status of req to STABLE if there are no attributes to restore
      if temp_record.nil?
        @cm_req.status = 1
        @cm_req.save
      end

      restored=true
      flash[:notice]='Traceability Element relations restored to last STABLE situation. ' + message
    end

    flash[:notice]='This Traceability Element has nothing to reject (no changes). ' unless restored
    
    redirect_to :action => 'show', :id => @cm_req
  end

  def change_log
    @temp_record=CmTempoReq.find(:first, :conditions => ["req_id=?", @cm_req.id])
    @temp_records=CmTempoReqsReq.find(:all, :conditions => ["cm_req_id=?", @cm_req.id])
  end

  def matrix
    # Show form with 2 select fields to get the req types to use in matrix
    @req_types = CmReqsType.find(:all, 
      :conditions => ["project_id in (?,?)", 0, @project.id])

    if request.post? or params[:format] == "cmdc"
      #Verify levels
      message_to_user=""
      if request.post?
        @te_1=CmReqsType.find(params[:cm_matrix][:te_1])
        @te_2=CmReqsType.find(params[:cm_matrix][:te_2])
      else
        @te_1=CmReqsType.find(params[:te_1])
        @te_2=CmReqsType.find(params[:te_2])
      end

      get_matrix=true

      if @te_1.nil? or @te_2.nil?
        message_to_user="Types not found. "
        get_matrix=false
      end

      if @te_1.level > @te_2.level and @te_1.level != (@te_2.level + 1)
        message_to_user=message_to_user + "Levels of selected types are not in sequence"
        get_matrix=false
      end

      if @te_1.level < @te_2.level and (@te_1.level + 1) != @te_2.level
        message_to_user=message_to_user + "Levels of selected types are not in sequence"
        get_matrix=false
      end

      if get_matrix
        @conta_ok=0; @conta_errors=0; @conta_warnings=0; @cover_percentage=0
        @matrix_table = []
        table_it = []
        # Do not include the DISMISSED requirements
        @reqs_te_1 = CmReq.find(:all, 
          :conditions => ['type_id=? and project_id=? and status<>?', @te_1.id, @project.id, 3],
            :order => "code ASC")

        @reqs_te_1.each do |te1|
          descendents=""
          if @te_1.level < @te_2.level
            te1.cm_reqs_reqs.each do |te2|
              #"Brothers" are not considered
              if te2.relation_type != 3
                descendents=descendents + " " + te2.child_req.code
              end
            end
          else
            reqs_parent = CmReqsReq.find(:all,
              :conditions => ['child_req_id=?', te1.id])

            reqs_parent.each do |te2|
              #"Brothers" are not considered
              if te2.relation_type != 3
                descendents=descendents + " " + te2.parent_req.code
              end
            end
          end
          if descendents.empty?
            if @te_1.level > @te_2.level
              if te1.no_ascendants
                descendents="WARNING"
                @conta_warnings+=1
              else
                descendents="ERROR"
                @conta_errors+=1
              end
            else
              if te1.no_descendants
                descendents="WARNING"
                @conta_warnings+=1
              else
                descendents="ERROR"
                @conta_errors+=1
              end
            end
          else
            @conta_ok+=1
          end
          table_it = [te1.code, descendents, te1.id]

          @matrix_table << table_it
        end

        # Sort final report based on descendants, in order to have all the
        # errors together
        @matrix_table.sort! { |a,b| b[1] <=> a[1] }

        tot=@conta_ok + @conta_errors + @conta_warnings
        covered=@conta_ok + @conta_warnings
        @cover_percentage=covered*100/tot

        flash[:notice]='Matrix generated successfully'
      else
        flash[:error]=message_to_user
      end
    end

    respond_to do |format|
      format.html { render(:template => 'cm_reqs/matrix.rhtml', :layout => !request.xhr?) }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_req_matrix_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_reqs/matrix_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-TEsMatrix.html")
      }
    end

  end

  def import_trace
    if request.post?
      all_ok=true
      rec_cnt=0
      @obj="CmReq"
      @caller_cont="cm_reqs"
      @input_mask="Ntype_id;Scode;Ntype_id;Scode;Ccompliance;Sassumption;Nauthor_id"

      if params[:cm_import_trace][:file_name].nil?
        flash[:error]='File Name must be completed before'
      else
        @tempo_file = params[:cm_import_trace][:file_name].local_path

        begin
          sql_columns, sql_values=import(@obj, @tempo_file,
          "TAB", @input_mask, @project.id, true)
        rescue RuntimeError => e
          flash[:error] = e.message
          return
        end

        sql_values.each do |ss|
          rec_cnt+=1

          # Search for req_id_1
          cm_req_1=CmReq.find(:first, :conditions => ["code=? and project_id=?",
          ss[1], ss[7]])
          if cm_req_1.nil?
            all_ok=false
            flash[:error]='TE 1 at record ' + ss[1] + rec_cnt.to_s + ' not found at DB!'
            break
          end
          # Search for req_id_2
          cm_req_2=CmReq.find(:first, :conditions => ["code=? and project_id=?",
          ss[3], ss[7]])
          if cm_req_2.nil?
            all_ok=false
            flash[:error]='TE 2 at record ' + ss[3] + rec_cnt.to_s + ' not found at DB!'
            break
          end
          # If compliance or assumption have changed, update them
          mod_req=false
          if cm_req_1.compliance != ss[4]
            cm_req_1.compliance=ss[4]
            mod_req=true
          end
          if cm_req_1.assumption != ss[5]
            cm_req_1.assumption=ss[5]
            mod_req=true
          end
          if mod_req
            #Save performing validations. False if some error is found
            unless cm_req_1.save(true)
              all_ok=false
              flash[:error]='Error saving TE 1 (' + cm_req_1.to_s + ')'
              break
            end
          end

          # Creates relation
          CmReqsReq.create(:cm_req_id => cm_req_1.id, :child_req_id => cm_req_2.id, :relation_type => 2,
          :author_id => ss[6], :created_on => ss[8])
        end
      end

      if all_ok
        flash[:notice]='All relationships created succesfully'
      end
      redirect_back_or_default({ :action => 'index', :id => @project})
    end

  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmReq, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmReq.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmReq.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmReq.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmReq.table_name}.classification_id = ?"
      values << params[:query3].to_i
    end

    unless params[:query4].blank?
      columns << " and #{CmReq.table_name}.subsystem_id = ?"
      values << params[:query4].to_i
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query5]='' if params[:query5]=="0"

    unless params[:query5].blank?
      columns << " and #{CmReq.table_name}.status = ?"
      values << params[:query5].to_i
    end

    unless params[:query6].blank?
      columns << " and #{CmReq.table_name}.updated_on > ?"
      values << DateTime.strptime(params[:query6], "%Y-%m-%d").to_time
      @date_created=DateTime.strptime(params[:query6], "%Y-%m-%d").to_time
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query7]='' if params[:query7]=="0"

    unless params[:query7].blank?
      if params[:query7] == "-1"
        columns << " and #{CmReq.table_name}.assigned_to_id is NULL"
      else
        columns << " and #{CmReq.table_name}.assigned_to_id = ?"
        values << params[:query7].to_i
      end
    end

    unless params[:query8].blank?
      columns << " and #{CmReq.table_name}.version = ?"
      values << "#{params[:query8]}"
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query9]='' if params[:query9]=="0"

    unless params[:query9].blank?
      columns << " and #{CmReq.table_name}.compliance = ?"
      values << params[:query9].to_i
    end    

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos()
      if @cm_req.type.blank?
        @cm_req.type = CmReqsType.default(@project.id)
        unless @cm_req.type
          render_error "The Traceability Elements have no Type set as default!"
          return
        end
      end
#      @cm_soc_control if @cm_req.type.
#      logger.error("SCO_CONTROL:" + @cm_soc_control.to_s)
      if @cm_req.classification.blank?
        @cm_req.classification = CmReqsClassification.default(@project.id)
        unless @cm_req.classification
          render_error "The Traceability Elements have no Classification set as default!"
          return
        end
      end
      if params[:req_level]
        @cm_req_types = CmReqsType.find(:all, 
          :conditions => ["level = ? and project_id in (?,?)", params[:req_level].to_i, 0, @project.id])
        @coming_from_other_Req="Y"
        @father_id=params[:req_id]
      else
        @cm_req_types = CmReqsType.find(:all, 
          :conditions => ['project_id in (?,?)', 0, @project.id])
        @father_id=nil
      end
      @cm_req_assignees = @project.assignable_users
      unless @cm_req_assignees
        render_error "There are no users assigned to the Project!"
        return
      end
      @cm_req_classifications = CmReqsClassification.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
      # Counter Type selection. Some objects, like this, include an extra option
      # for selecting a counter type directly related to the object type
      @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Traceability Element'))
      @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))

      @verif_methods = CmTestVerificationMethod.find(:all)

      #Get parent reqs. Rel type has to be different from 3 (brothers)
      @parent_reqs = CmReqsReq.find(:all, :conditions => ['child_req_id = ?', @cm_req.id])
  end

  def find_cm_req
# do not bring the asignee nor the releases... just to try
    @cm_req = CmReq.find(params[:id], :include => [:project, :type, :author, :subsystem, :classification])
    @project = @cm_req.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def get_children (myReq, myInfo, indent, related)

    myindent = indent + 2
    related.each do |childreq|

      @cm_info = CmReq.new
      @cm_info.classification_id = myReq.id

      sonReq = CmReq.find(childreq.child_req.id, :include => [:cm_reqs_reqs])

      @cm_info.id=sonReq.id; @cm_info.code=sonReq.code; @cm_info.name=sonReq.name
      @cm_info.type_id=sonReq.type_id; @cm_info.status=sonReq.status
      @cm_info.display_order=myindent

      son_related_reqs=CmReqsReq.find(:all,
          :conditions => ['cm_req_id = ? and relation_type != ?',sonReq.id, 3])
      if son_related_reqs.any?
        @cm_info.verification_method_id = 1
        myInfo << @cm_info
        get_children(sonReq, myInfo, indent+2, son_related_reqs)
      else
        @cm_info.verification_method_id = 0
        myInfo << @cm_info
      end
    end
  end

  def managed_tempo_record

    # Reqs in DISMISS status can be deleted
    return false if @cm_req.status == 3

    temp_record=CmTempoReq.find(:first, :conditions => ["req_id=?", @cm_req.id])
    if temp_record
      #If tempo exists, STATUS must to be stable
      temp_record.action="DELETE"
      temp_record.save
      flash[:notice] = "Traceability Element already in proposed status, proposed now for deletion"

      return true
    else
      temp_rel_record=CmTempoReqsReq.find(:first,
        :conditions => ["cm_req_id=?", @cm_req.id])

      #Delete for Stable reqs
      if @cm_req.status == 1 or temp_rel_record
        CmTempoReq.create(:req_id => @cm_req.id,
          :code => @cm_req.code,
          :name => @cm_req.name,
          :description => @cm_req.description,
          :version => @cm_req.version,
          :type_id => @cm_req.type_id,
          :classification_id => @cm_req.classification_id,
          :subsystem_id => @cm_req.subsystem_id,
          :verification_method_id => @cm_req.verification_method_id,
          :no_ascendants => @cm_req.no_ascendants,
          :no_descendants => @cm_req.no_descendants,
          :optional => @cm_req.optional,
          :status => @cm_req.status,
          :assigned_to_id => @cm_req.assigned_to_id,
          :display_order => @cm_req.display_order,
          :place_in_doc => @cm_req.place_in_doc,
          :project_id => @cm_req.project_id,
          :author_id => @cm_req.author_id,
          :created_on => @cm_req.created_on,
          :updated_on => @cm_req.updated_on,
          :action => "DELETE")

        #Change status to proposed
        @cm_req.status=2
        @cm_req.save

        flash[:notice] = "Traceability Element changes from stable to proposed for deletion"
        return true
      end
    end

    return false
  end

  def do_approval_process
    temp_record=CmTempoReq.find(:first, :conditions => ["req_id=?", @cm_req.id])
    if temp_record.nil?
      @cm_req.status=1
      @message="Status changed to STABLE"
      # Set version for new reqs
      @cm_req.version=@version_new unless @version_new.blank?
    else
      case temp_record.action
      when "EDIT"
        @cm_req.status=1
        @message="Status changed to STABLE"
      when "DELETE"
        # Deleted Traceability Elements pass to Dismissed with a comment in the description
        @cm_req.status=3
        @cm_req.comments="[Dismissed after approve its Deletion] " + @cm_req.comments
        @message="Status changed to DIMISSED (logical delete)"
      when "DISMISS"
        #If proposed change is to DISMISS the req
        @cm_req.status=3
        @cm_req.comments="[Dismissed after approve the Dismiss request] " + @cm_req.comments
        @message="Traceability Element DISMISSED"
      end
      temp_record.destroy
      @cm_req.version=@version_modified unless @version_modified.blank?
    end

    # Delete all the tempo records associated (if any)
    CmTempoReqsReq.delete_all(:cm_req_id => @cm_req.id)
  end
end
