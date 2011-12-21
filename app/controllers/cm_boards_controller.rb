class CmBoardsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_board, :only => [:show, :edit, :destroy, :remove_relation, :reopen]
  before_filter :find_project, :only => [:new, :index, :pending_actions]
  before_filter :authorize, :except => [:pending_actions, :remove_relation]

  accept_key_auth :show, :index, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :sort
  include SortHelper
  helper :cm_changes_objects
  include CmChangesObjectsHelper
  helper :cm_ncs_objects
  include CmNcsObjectsHelper
  include CmBoardsHelper
  helper :attachments
  include AttachmentsHelper
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
    sort_update %w(id cm_board_code meeting_date)

    #define filter capabilities
    if @cm_board_types.nil?
      @cm_board_types = CmBoardType.find(:all, :conditions => ['project_id in (?, ?)', 0, @project.id])
      @cm_board_types.insert(0, CmBoardType.new(:name => "All", :id => 0))
    end
    
    conditions=prepare_filter()
    @total = CmBoard.count(:conditions => conditions)
    
    @cm_board_pages, @cm_boards = paginate :cm_boards, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:type, :company]

    respond_to do |format|
      format.html { render(:template => 'cm_boards/index.rhtml', :layout => !request.xhr?) }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_meeting_index_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_boards/index_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-MeetingsList.html")
      }
    end

  end
          
  def show
    prepare_combos()

    @journals = @cm_board.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_boards/show.rhtml' }
      format.pdf  { send_data(cm_board_to_pdf(@cm_board), :type => 'application/pdf',
         :filename => "#{@cm_board.cm_board_code}.pdf") }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_meeting_show_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_boards/show_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-Meeting#{@cm_board.id}.html") }
    end
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_board.init_journal(User.current, @notes)
     
    if params[:cm_board]
      attrs = params[:cm_board].dup
      @cm_board.attributes = attrs
    end
 
     if request.post?
       if @cm_board.valid?
         call_hook(:controller_cm_board_edit_before_save, { :params => params, :cm_board => @cm_board, :journal => journal})
         if @cm_board.save
           if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
           end
           call_hook(:controller_cm_board_edit_after_save, { :params => params, :cm_board => @cm_board, :journal => journal})

           Attachment.attach_files(@cm_board, params[:attachments])
           render_attachment_warning_if_needed(@cm_board)
           
           # Deliver email
           Mailer.deliver_cmdc_info(User.current, @project, @cm_board, 'cm_boards')

           redirect_back_or_default({:action => 'show', :id => @cm_board})
         else
            flash[:error] = "Edit not performed!!"
         end
       else
         flash[:error] = "Validation Error!!"
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
   end
  
  def new
    if request.get?
      # Control COPY option
      if params[:copy_board_id]
        prepare_board_with_copy_data()
      else
        @cm_board = CmBoard.new(:project => @project)
        @cm_board.author = User.current
      end

      prepare_combos()
    end
    
    if request.post?
      @cm_board = CmBoard.new(params[:cm_board])
      @cm_board.project = @project
      @cm_board.author = User.current
      prev_code = @cm_board.cm_board_code
      @cm_board.counter_type=params[:counter_type].to_i

      @cm_board.watcher_user_ids=params[:cm_board]['watcher_user_ids']

      if @cm_board.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_board.cm_board_code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_board.cm_board_code
        end

        Attachment.attach_files(@cm_board, params[:attachments])
        render_attachment_warning_if_needed(@cm_board)

        # Deliver email
        Mailer.deliver_cmdc_info(User.current, @project, @cm_board, 'cm_boards')
        
        redirect_back_or_default({ :action => 'show', :id => @cm_board })
      else
        prepare_combos()

        flash[:error] = 'Error creating Meeting'
      end              
    end   
  end
     
  def destroy
    @cm_board.destroy
    redirect_to :action => 'index', :id => @project
  end

  def reopen
    @cm_board.init_journal(User.current, "")
    @cm_board.participants = '*@*' + @cm_board.participants
    @cm_board.minutes_closed = false
    if @cm_board.save
      flash[:notice] = "Meeting reopened!"
    end
    redirect_back_or_default({ :action => 'show', :id => @cm_board })
  end

  def pending_actions
    #Get boards of the project with issues not closed. Issues from this or whatever
    #the project (just could be for child projects... in theory)
    @cm_pending_actions = CmObjectsIssue.find(:all,
      :conditions => ['cm_objects_issues.cm_object_type=? AND cm_boards.project_id=?
                       AND issue_statuses.is_closed=?',"CmBoard", @project.id, false],
      :joins => 'LEFT JOIN cm_boards ON cm_object_id=cm_boards.id
                 LEFT JOIN issues ON issue_id=issues.id
                 LEFT JOIN issue_statuses ON issues.status_id=issue_statuses.id',
      :select => 'cm_boards.cm_board_code, issues.subject, issue_statuses.name, cm_boards.meeting_date,
                  issues.due_date, cm_objects_issues.cm_object_id, cm_objects_issues.issue_id',
      :order => 'cm_objects_issues.cm_object_id')

    # Those meetings with the all the actions closed are updated
    @cm_boards = CmBoard.find(:all, :conditions => ['project_id = ?', @project.id])

    # Create array just with codes for using include? method later
    pending = []
    @cm_pending_actions.each do |pen|
      pending << pen.cm_board_code
    end

    meetings_pending=""
    meetings_complete=""
    @cm_boards.each do |board|     
      if pending.include?(board.cm_board_code)
        if board.actions_completed
          # Remove mark
          board.init_journal(User.current, "")
          board.participants = '*@*' + board.participants
          board.actions_completed = false
          flash[:error] = "Meeting " + board.cm_board_code + " can not be modifed" unless board.save
          meetings_pending = meetings_pending + board.cm_board_code + "  "
        end
      else
        unless board.actions_completed
          # Set mark
          board.init_journal(User.current, "")
          board.participants = '*@*' + board.participants
          board.actions_completed = true
          flash[:error] = "Meeting " + board.cm_board_code + " can not be modifed" unless board.save
          meetings_complete = meetings_complete + board.cm_board_code + "  "
        end        
      end
      
    end

    if meetings_pending.empty?
      meetings_pending="Meetings set as Actions Pending: None "
    else
      meetings_pending="Meetings set as Actions Pending: " + meetings_pending
    end

    if meetings_complete.empty?
      meetings_complete="Meetings set as Actions Completed: None "
    else
      meetings_complete="Meetings set as Actions Completed: " + meetings_complete
    end
    flash[:notice] = meetings_pending + " - " + meetings_complete

  end

  private
  
  def find_cm_board
    @cm_board = CmBoard.find(params[:id], :include => [:project, :company, :author, :type])
    @project = @cm_board.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmBoard, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmBoard.table_name}.cm_board_code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmBoard.table_name}.type_id = ?"
      values << params[:query1].to_i
    end

    unless params[:query2].blank?
      columns << " and #{CmBoard.table_name}.subject LIKE ?"
      values << "%#{params[:query2]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_board_types = CmBoardType.find(:all, :conditions => ['project_id in (?, ?)', 0, @project.id])
    @cm_companies = CmCompany.find(:all, :conditions => ['project_id=?', @project.id])
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Meeting'))
    @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))
  end

  def prepare_board_with_copy_data
    cm_board_to_copy = CmBoard.find(params[:copy_board_id])
    @cm_board = cm_board_to_copy.clone
    @cm_board.cm_board_code = ""
    @cm_board.action_counter = 0
    @cm_board.actions_completed = false
    @cm_board.minutes_closed = false
    @cm_board.project = @project
  end
end
