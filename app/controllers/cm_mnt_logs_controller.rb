class CmMntLogsController < ApplicationController
  before_filter :find_cm_mnt_log, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize

  accept_key_auth :show, :edit, :destroy  
  
  helper :attachments
  include AttachmentsHelper
  helper :journals
  include JournalsHelper
  helper :sort
  include SortHelper
  helper :cm_common
  include CmCommonHelper
  
  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }  
                      
  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id cm_item_id name maintenance_start_date)

    #define filter capabilities
    if @cm_mnt_log_statuses.nil?
      @cm_mnt_log_statuses = CmMntLogStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_mnt_log_statuses.insert(0, CmMntLogStatus.new(:name => "All", :id => 0))
    end

    conditions=prepare_filter()

    @total = CmMntLog.count(:conditions => conditions)

    @cm_mnt_log_pages, @cm_mnt_logs = paginate :cm_mnt_logs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:item, :installer, :type, :status]

    if request.xml_http_request?
      render(:template => 'cm_mnt_logs/index.rhtml', :layout => !request.xhr?)
    end
  end           
                               
  def show
    prepare_combos()

    @journals = @cm_mnt_log.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_mnt_log.init_journal(User.current, @notes)

    if params[:cm_mnt_log]
      attrs = params[:cm_mnt_log].dup
      @cm_mnt_log.attributes = attrs
    end      
    
    if request.post?
      if @cm_mnt_log.valid?
        call_hook(:controller_cm_mnt_logs_edit_before_save, { :params => params, :cm_mnt_log => @cm_mnt_log, :journal => journal})
        if @cm_mnt_log.save
          attachments = Attachment.attach_files(@cm_mnt_log, params[:attachments])
          render_attachment_warning_if_needed(@cm_mnt_log)

          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_mnt_logs_edit_after_save, { :params => params, :cm_mnt_log => @cm_mnt_log, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_mnt_log})
        else
          flash[:error] = "Edit not performed!!"
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
      @cm_mnt_log = CmMntLog.new
      @cm_mnt_log.project = @project
      @cm_mnt_log.author = User.current
      @cm_mnt_log.maintenance_start_date = Time.now

      default_status = CmMntLogStatus.default(@project.id)
      unless default_status
        render_error l(:error_no_default_cm_mnt_log_status)
        return
      end
      @cm_mnt_log.status = default_status
    end  
    
    if request.post?                        
      @cm_mnt_log = CmMntLog.new(params[:cm_mnt_log])
      @cm_mnt_log.author = User.current
      @cm_mnt_log.project = @project
      prev_code = @cm_mnt_log.code
           
      if @cm_mnt_log.save
        if prev_code != @cm_mnt_log.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_mnt_log.code
        end
        Attachment.attach_files(@cm_mnt_log, params[:attachments])
        render_attachment_warning_if_needed(@cm_mnt_log)

        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'show', :id => @cm_mnt_log })
      else              
        flash[:error] = 'Error saving ,maintenance log'
      end              
    end       
  end

  def destroy
    @cm_mnt_log.destroy
    redirect_to :action => 'index', :id => @project
  end

  #Private area
  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmMntLog, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmMntLog.table_name}.name LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmMntLog.table_name}.status_id = ?"
      values << params[:query1].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_mnt_log_types = CmMntLogType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_mnt_log_statuses = CmMntLogStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_mnt_log_users = @project.assignable_users
    @iitems = CmItem.find(:all, :conditions => ['project_id=?', @project.id])
  end

  def find_cm_mnt_log
    @cm_mnt_log = CmMntLog.find(params[:id], :include => [:project, :installer, :status, :author, :type])
    @project = @cm_mnt_log.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end    
end
