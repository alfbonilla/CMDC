class CmDocsController < ApplicationController
  before_filter :find_cm_doc, :only => [:show, :edit, :destroy, :get_changes_log]
  before_filter :find_project, :only => [:new, :index, :coming_from_counters]
  before_filter :authorize, :except => [:coming_from_counters, :get_changes_log]

  accept_key_auth :show, :edit, :destroy  
  
  helper :attachments
  include AttachmentsHelper
  helper :journals
  include JournalsHelper
  helper :sort
  include SortHelper
  include ApplicationHelper
  include CmDocsHelper
  helper :cm_rids
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
    sort_update %w(id code name type_id)

    #define filter capabilities
    conditions=prepare_filter()

    if @cm_doc_types.nil?
      @cm_doc_types = CmDocType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_doc_types.insert(0, CmDocType.new(:name => "All", :id => 0))
    end

    if @cm_doc_boolean.nil?
       @cm_doc_boolean = {'All' => 0, 'Deliverable' => 1, 'No Deliverable' => 2}
    end

    if @cm_doc_statuses.nil?
      @cm_doc_statuses = CmDocStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_doc_statuses.insert(0, CmDocStatus.new(:name => "All", :id => 0))
    end

    if @cm_companies.nil?
      @cm_companies = CmCompany.find(:all, :conditions => ['project_id=?', @project.id])
      @cm_companies.insert(0, CmCompany.new(:name => "All", :id => 0))
    end

    if params[:query5].blank?
      @filter_by_status=false
      @last_status=""
    else
      @filter_by_status=true
      @last_status=params[:query5].to_i
    end

    @total = CmDoc.count(:conditions => conditions)

    @cm_doc_pages, @cm_docs = paginate :cm_docs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:type, :category, :cm_docs_versions]

    if request.xml_http_request?
      render(:template => 'cm_docs/index.rhtml', :layout => !request.xhr?)
    end
  end           
                               
  def show
    prepare_combos()

    @cm_qrs = CmQr.find(:all, :conditions => [ "x_id = ? and x_type = ? and project_id = ?",
        @cm_doc.id, "Document", @project.id])

    @journals = @cm_doc.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_doc.init_journal(User.current, @notes)

    if params[:cm_doc]
      attrs = params[:cm_doc].dup
      @cm_doc.attributes = attrs
    end      
    
    if request.post?
      if @cm_doc.valid?
        call_hook(:controller_cm_docs_edit_before_save, { :params => params, :cm_doc => @cm_doc, :journal => journal})
        if @cm_doc.save
          Attachment.attach_files(@cm_doc, params[:attachments])
          render_attachment_warning_if_needed(@cm_doc)

          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update) if !journal.new_record?

          call_hook(:controller_cm_docs_edit_after_save, { :params => params, :cm_doc => @cm_doc, :journal => journal})
          
          redirect_back_or_default({:action => 'show', :id => @cm_doc})
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
    if request.get?
      prepare_combos()

      # Create, Clone and Continue option
      if params[:cm_doc]
        @cm_doc = CmDoc.new(params[:cm_doc])
        @cm_doc.code = ""
        # Restore status as it is set with the default value in the after_initialize method
        @cm_doc.l_status_id = params[:cm_doc][:l_status_id].to_i
        @cm_doc.project = @project
      else
        # Control COPY option
        if params[:copy_doc_id]
          prepare_doc_with_copy_data()
        else
          # Regular option
          @cm_doc = CmDoc.new(:project => @project)
        end
      end
      
      @cm_doc.author = User.current
    end
    
    if request.post?
      @cm_doc = CmDoc.new(params[:cm_doc])
      @cm_doc.project = @project
      @cm_doc.author = User.current
      prev_code = @cm_doc.code
      @cm_doc.counter_type=params[:counter_type].to_i

      @cm_doc.watcher_user_ids=params[:cm_doc]['watcher_user_ids']

      if @cm_doc.save
        Attachment.attach_files(@cm_doc, params[:attachments])
        render_attachment_warning_if_needed(@cm_doc)
       
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_doc.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_doc.code
        end

        if params[:continue]
          redirect_to :action => 'new', :id => @project, :cm_doc => params[:cm_doc]
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_doc })
        end
      else
        #Recover info in case of error
        prepare_combos()
                
        flash[:error] = 'Error creating Document'
      end              
    end       
  end

  def destroy
    begin
      @cm_doc.destroy
    rescue RuntimeError => e
      flash[:error]='Document not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end

  def get_changes_log
    # Get all RIDS associated to document with the implementation_location completed!
    if request.post?
      @changes_log="List of implemented RIDs:"
      @codes_to_get=params[:codes_to_get]
      code_with_mask="%" + params[:codes_to_get] + "%"

      @affected_rids=CmRid.find(:all, :conditions => ['affected_doc_id=? and code like ?',
                      @cm_doc.id, code_with_mask], :order => 'code')
      if @affected_rids.any?
        @affected_rids.each do |rid|
          @changes_log=@changes_log + "\r" + rid.code + ": " + rid.implementation_location unless rid.implementation_location.blank?
        end
      else
        flash[:error]="There are no RIDS associated to the doc with that code"
      end

      flash[:notice]="There are RIDS associated, but no implementation completed!" if @change_log == "List of implemented RIDs:"

      flash[:notice]="Change Log completed successfully"
    end

  end

  #Private area
  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmDoc, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmDoc.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmDoc.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmDoc.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    params[:query4]='' if params[:query4]=="0"

    unless params[:query4].blank?
      columns << " and #{CmDoc.table_name}.deliverable = ?"
      if params[:query4]=="1"
        values << true
      else
        values << false
      end
    end

    unless params[:query6].blank?
      columns << " and #{CmDoc.table_name}.external_doc_id LIKE ?"
      values << "%#{params[:query6]}%"
    end

    unless params[:query7].blank?
      columns << " and #{CmDoc.table_name}.originator_company_id = ?"
      values << params[:query7].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_doc_types = CmDocType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_doc_statuses = CmDocStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_doc_categories = DocumentCategory.all
    @cm_companies = CmCompany.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_doc_assignees = @project.assignable_users
    unless @cm_doc_assignees
      render_error "There are no users assigned to the Project!"
      return
    end
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Document'))
    @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))

    @deliveries = CmDeliveriesObject.find(:all,
        :conditions => ['cm_deliveries_objects.x_id=? AND cm_deliveries_objects.x_type=?',
        @cm_doc.id, "CmDoc"])
  end

  def find_cm_doc
    @cm_doc = CmDoc.find(params[:id], :include => [:project, :author, :type, :company, :category])
    @project = @cm_doc.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end

  def prepare_doc_with_copy_data
    cm_doc_to_copy = CmDoc.find(params[:copy_doc_id])
    @cm_doc = cm_doc_to_copy.clone
    # Prepare local data with data from last_version (if any)
    @cm_doc.l_version = cm_doc_to_copy.last_version.version
    @cm_doc.l_applicable = cm_doc_to_copy.last_version.applicable
    @cm_doc.l_assigned_to_id = cm_doc_to_copy.last_version.assigned_to_id
    @cm_doc.l_physical_location = cm_doc_to_copy.last_version.physical_location
    @cm_doc.l_status_id = cm_doc_to_copy.last_version.status_id
    @cm_doc.code = ""
    @cm_doc.project = @project
  end
end
