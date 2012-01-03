class CmRidsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_rid, :only => [:show, :edit, :destroy, :summary]
  before_filter :find_project, :only => [:index, :new, :get_statistics]
  before_filter :authorize, :except => [:remove_relation, :get_statistics]

  accept_key_auth :index, :show, :edit, :new, :destroy, :remove_relation
  
  helper :journals
  include JournalsHelper
  helper :projects
  include ProjectsHelper
  helper :sort
  include SortHelper
  helper :attachments
  include AttachmentsHelper
  include CmRidsHelper
  helper :watchers
  include WatchersHelper
  helper :cm_common
  include CmCommonHelper
  
  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }

  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id code)
    
    #define filter capabilities
    conditions=prepare_filter()

    @cm_rid_statuses = {'All' => 0, change_internal_status_to_s(1) => 1,
      change_internal_status_to_s(2) => 2, change_internal_status_to_s(3) => 3,
      change_internal_status_to_s(4) => 4} if @cm_rid_statuses.nil?

    @cm_rid_categories = {'All' => 0, change_category_to_s(1) => 1,
      change_category_to_s(2) => 2, change_category_to_s(3) => 3,
      change_category_to_s(4) => 4} if @cm_rid_categories.nil?

    #Get assignable users and add All and Not Assigned options
    rid_assignees = @project.assignable_users
    tmp_rid_assignees = {"Not Assigned" => -1}
    rid_assignees.each do |assignee|
      tmp_rid_assignees[assignee.name] = assignee.id
    end
    tmp_rid_assignees["All"] = 0
    @cm_rid_assignees=tmp_rid_assignees.sort_by { |k,v| v }

    @total = CmRid.count(:conditions => conditions)

    @cm_rid_pages, @cm_rids = paginate :cm_rids, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:close_out, :originator_company, :affected_doc]

    respond_to do |format|
      format.html { render(:template => 'cm_rids/index.rhtml', :layout => !request.xhr?) }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_rid_index_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_rids/index_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-RidsList.html")
      }
    end

  end

  def show
    prepare_combos()

    @journals = @cm_rid.journals.find(:all, :include => [:user, :details],
                            :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_rids/show.rhtml' }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_rid_show_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_rids/show_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-RID#{@cm_rid.id}.html") }
    end

  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_rid.init_journal(User.current, @notes)
     
    if params[:cm_rid]
      attrs = params[:cm_rid].dup
      @cm_rid.attributes = attrs
    end
 
    if request.post?
      if @cm_rid.valid?
        call_hook(:controller_cm_rids_edit_before_save, { :params => params, :cm_rid => @cm_rid, :journal => journal})
        if @cm_rid.save
          create_relation_with_board

          attachments = Attachment.attach_files(@cm_rid, params[:attachments])
          render_attachment_warning_if_needed(@cm_rid)

          if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_rids_edit_after_save, { :params => params, :cm_rid => @cm_rid, :journal => journal})

          Mailer.deliver_cmdc_info(User.current, @project, @cm_rid, 'cm_rids')

          redirect_back_or_default({:action => 'show', :id => @cm_rid})
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
    prepare_combos()
    
    if request.get?

      if params[:cm_rid]
        @cm_rid = CmRid.new(params[:cm_rid])
        @cm_rid.code = ""
        @cm_rid.project = @project
      else
        @cm_rid = CmRid.new(:project => @project)
        @cm_rid.generation_date = Time.now
      end
      @cm_rid.originator = User.current.name
      @cm_rid.author = User.current
      default_close_out = CmRidCloseOut.default(@project.id)
      unless default_close_out
        render_error l(:error_no_default_cm_rid_close_out)
        return
      end
      @cm_rid.close_out = default_close_out
    end

    if request.post?     
      @cm_rid = CmRid.new(params[:cm_rid])
      @cm_rid.project = @project
      @cm_rid.author = User.current
      prev_code = @cm_rid.code

      if @cm_rid.save
        create_relation_with_board

        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_rid.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_rid.code
        end
        Attachment.attach_files(@cm_rid, params[:attachments])
        render_attachment_warning_if_needed(@cm_rid)

        Mailer.deliver_cmdc_info(User.current, @project, @cm_rid, 'cm_rids')

        if params[:continue]
          redirect_to :action => 'new', :id => @project, :cm_rid => params[:cm_rid]
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_rid })
        end
        
      else
        flash[:error] = 'Error saving rid'
      end              
    end   
  end
     
  def destroy
    begin
      @cm_rid.destroy
    rescue RuntimeError => e
      flash[:error]='Rid not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end

  def summary
    @cm_rids_boards = CmRidsObject.find(:all,
          :conditions => ['a.x_id=b.id and a.cm_rid_id=? and a.x_type=?', @cm_rid.id, "CmBoard"],
          :joins => 'a, cm_boards b',
          :select => 'b.cm_board_code, b.meeting_date, a.target_version_id, a.rel_string, a.rel_date, a.rel_bool, a.x_id')
  end

  def get_statistics
    if request.post?
      @codes_to_approve=params[:codes_to_approve]
      code_with_mask="%" + params[:codes_to_approve] + "%"
      
      @rids_status = CmRid.find(:all, :select => "internal_status_id, count(*) AS count_by_status",
        :conditions => ['project_id=? and code like ?', @project, code_with_mask],
        :group => "internal_status_id")

      @rids_close_out = CmRid.find(:all, :select => "close_out_id, count(*) AS count_by_close_out",
        :conditions => ['project_id=? and code like ?', @project, code_with_mask],
        :group => "close_out_id")

      @rids_implemented = CmRid.find(:all, :select => "count(*) AS count_by_implementation",
        :conditions => ['project_id=? and code like ? and implementation_location <> "" ',
        @project, code_with_mask])

      @rids_reviewed = CmRid.find(:all, :select => "count(*) AS count_by_reviewed",
        :conditions => ['project_id=? and code like ? and reviewed = ? ',
        @project, code_with_mask, 1])

      @tot_rids=0
      @rids_status.each do |rid|
        @tot_rids+=rid.count_by_status.to_i
      end
    end
  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmRid, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmRid.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmRid.table_name}.problem_location LIKE ?"
      values << "%#{params[:query1]}%"
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query2]='' if params[:query2]=="0"

    unless params[:query2].blank?
      columns << " and #{CmRid.table_name}.internal_status_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmRid.table_name}.originator LIKE ?"
      values << "%#{params[:query3]}%"
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query4]='' if params[:query4]=="0"

    unless params[:query4].blank?
      columns << " and #{CmRid.table_name}.category = ?"
      values << params[:query4].to_i
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query5]='' if params[:query5]=="0"

    unless params[:query5].blank?
      if params[:query5] == "-1"
        columns << " and #{CmRid.table_name}.assigned_to_id is NULL"
      else
        columns << " and #{CmRid.table_name}.assigned_to_id = ?"
        values << params[:query5].to_i
      end
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_rid_close_outs = CmRidCloseOut.find(:all, 
      :conditions => ['project_id in (?,?)',0 , @project.id])
    @cm_companies = CmCompany.find(:all)
    @releases = Version.find(:all, :conditions => ['status = ? and project_id = ?', "open", @project.id])
    @cm_rid_assignees = @project.assignable_users
      unless @cm_rid_assignees
        render_error "There are no users assigned to the Project!"
        return
      end
    @cm_docs = CmDoc.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_boards = CmBoard.find(:all, :conditions => ['project_id=? and minutes_closed=?', @project.id, false])
  end

  def find_cm_rid
    @cm_rid = CmRid.find(params[:id], :include => [:project, :close_out, :author, :originator_company])
    @project = @cm_rid.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def create_relation_with_board
    unless @cm_rid.board_to_relate.blank?
      # Create relationship with Board
      j=CmRidsObject.new(:cm_rid_id => @cm_rid.id, :x_id => @cm_rid.board_to_relate,
        :x_type => "CmBoard", :rel_string => @cm_rid.close_out.name,
        :target_version_id => @cm_rid.implementation_release_id,
        :created_on => Time.now, :author => User.current )
      j.errors.each_full { |msg| flash[:error] = "Error creating Relation with Meeting:" + msg } unless j.save
    end
  end
end
