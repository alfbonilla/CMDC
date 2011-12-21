class CmChangesController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_change, :only => [:show, :edit, :destroy, :new_issue, :summary]
  before_filter :find_project, :only => [:index, :new, :index_tree]
  before_filter :authorize, :except => [:remove_relation, :new_issue, :summary]

  accept_key_auth :index, :show, :edit, :new, :destroy, :remove_relation
  
  helper :journals
  include JournalsHelper
  helper :projects
  include ProjectsHelper
  helper :sort
  include SortHelper
  helper :attachments
  include AttachmentsHelper
  helper :cm_common
  include CmCommonHelper
  include CmChangesHelper
  helper :cm_changes_objects
  include CmChangesObjectsHelper
  helper :watchers
  include WatchersHelper

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

    if @cm_change_types.nil?
      @cm_change_types = CmChangeType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_change_types.insert(0, CmChangeType.new(:name => "All", :id => 0))
    end

    if @cm_change_statuses.nil?
      @cm_change_statuses = CmChangeStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_change_statuses.insert(0, CmChangeStatus.new(:name => "All", :id => 0))
    end

    @cm_change_implementation = {'All' => 0, change_implementation_to_s(1) => 1,
      change_implementation_to_s(2) => 2, change_implementation_to_s(3) => 3} if @cm_change_implementation.nil?

    @total = CmChange.count(:conditions => conditions)

    @cm_change_pages, @cm_changes = paginate :cm_changes, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:status, :type, :source_company]

    if request.xml_http_request?
      render(:template => 'cm_changes/index.rhtml', :layout => !request.xhr?)
    end
  end

  def index_tree
    @cm_changes = CmChange.find(:all, :conditions => ["project_id = ?", @project.id], :include => [:cm_child_changes])

    #Prepare list
    @cm_info_changes = []
    @cm_changes.each do |change|

      @cm_info = CmChange.new

      #cm_change fields are used for managing the new list, replacing original info (not shown in the list)
      #with special values neccessary for seeing the structure as a tree:
      #   - implementation USED FOR indicating if the change has children
      #   - classification USED FOR saving the parent change id
      #   - compliance USED FOR saving the indentation value
      #If id is not already included
      if( !(@cm_info_changes.detect {|pid| pid.id == change.id }))
        @cm_info.id=change.id; @cm_info.code=change.code; @cm_info.name=change.name;
        @cm_info.type_id=change.type_id; @cm_info.status_id=change.status_id
        @cm_info.classification=0; @cm_info.compliance=0

        if change.cm_child_changes.any?
          @cm_info.implementation = 1
          @cm_info_changes << @cm_info
          get_children(change, @cm_info_changes, 0)
        else
          @cm_info.implementation = 0
          @cm_info_changes << @cm_info
        end
      end
    end

    @total = @cm_changes.count

    if request.xml_http_request?
      render(:template => 'cm_changes/index_tree.rhtml', :layout => !request.xhr?)
    end
  end

  def show
    prepare_combos()

    @journals = @cm_change.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
    
    respond_to do |format|
      format.html { render :template => 'cm_changes/show.rhtml' }
      format.pdf  { send_data(cm_change_to_pdf(@cm_change, params[:history]), :type => 'application/pdf',
                    :filename => "#{@project.identifier}-#{@cm_change.id}.pdf") }
    end
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_change.init_journal(User.current, @notes)
     
    if params[:cm_change]
      attrs = params[:cm_change].dup
      @cm_change.attributes = attrs
    end
 
    if request.post?
      if @cm_change.valid?
        call_hook(:controller_cm_changes_edit_before_save, { :params => params, :cm_change => @cm_change, :journal => journal})
        if @cm_change.save
          attachments = Attachment.attach_files(@cm_change, params[:attachments])
          render_attachment_warning_if_needed(@cm_change)

          if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_changes_edit_after_save, { :params => params, :cm_change => @cm_change, :journal => journal})

          Mailer.deliver_cmdc_info(User.current, @project, @cm_change, 'cm_changes')

          redirect_back_or_default({:action => 'show', :id => @cm_change})
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
      if params[:cm_change]
        @cm_change = CmChange.new(params[:cm_change])
        @cm_change.code = ""
        @cm_change.project = @project
      else
        @cm_change = CmChange.new(:project => @project)
      end
      @cm_change.author = User.current
      default_status = CmChangeStatus.default(@project.id)
      unless default_status
        render_error l(:error_no_default_cm_change_status)
        return
      end
      @cm_change.status = default_status
    end
      
    if request.post?     
      @cm_change = CmChange.new(params[:cm_change])
      @cm_change.project = @project
      @cm_change.author = User.current
      prev_code = @cm_change.code
      @cm_change.counter_type = params[:counter_type].to_i

      if @cm_change.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_change.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_change.code
        end
        Attachment.attach_files(@cm_change, params[:attachments])
        render_attachment_warning_if_needed(@cm_change)

        Mailer.deliver_cmdc_info(User.current, @project, @cm_change, 'cm_changes')

        if params[:continue]
          redirect_to :action => 'new', :id => @project, :cm_change => params[:cm_change]
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_change })
        end
      else
        flash[:error] = 'Error creating Change'
      end              
    end   
  end

  def destroy
    begin
      @cm_change.destroy
    rescue RuntimeError => e
      flash[:error]='Change not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end

  def summary
    @cm_changes_boards = CmChangesObject.find(:all,
          :conditions => ['a.x_id=b.id and a.cm_change_id=? and a.x_type=?', @cm_change.id, "CmBoard"],
          :joins => 'a, cm_boards b',
          :select => 'b.cm_board_code, b.meeting_date, a.target_version_id, a.rel_string, a.rel_date, a.rel_bool, a.x_id')
  end
  
  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmChange, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmChange.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmChange.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmChange.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmChange.table_name}.status_id = ?"
      values << params[:query3].to_i
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query4]='' if params[:query4]=="0"
        
    unless params[:query4].blank?
      columns << " and #{CmChange.table_name}.implementation = ?"
      values << params[:query4].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_change_statuses = CmChangeStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_change_types = CmChangeType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_companies = CmCompany.find(:all, :conditions => ['project_id=?', @project.id])
    @releases = Version.find(:all, :conditions => ['status = ? and project_id = ?', "open", @project.id])
    @cm_docs = CmDoc.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_items = CmItem.find(:all, :conditions => ['project_id=?', @project.id])
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Change'))
    @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))

    @deliveries = CmDeliveriesObject.find(:all,
        :conditions => ['cm_deliveries_objects.x_id=? AND cm_deliveries_objects.x_type=?',
        @cm_change.id, "CmChange"])
  end

  def find_cm_change
    @cm_change = CmChange.find(params[:id], :include => [:project, :status, :author, :type])
    @project = @cm_change.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def get_children (myChange, myInfo, indent)

    myindent = indent + 2
    myChange.cm_child_changes.each do |childchange|
      @cm_info = CmChange.new
      @cm_info.classification = myChange.id

      sonChange = CmChange.find(childchange.child_change_id, :include => [:cm_child_changes])

      @cm_info.id=sonChange.id; @cm_info.code=sonChange.code; @cm_info.name=sonChange.name
      @cm_info.type_id=sonChange.type_id; @cm_info.status_id=sonChange.status_id
      @cm_info.compliance=myindent

      if sonChange.cm_child_changes.any?
        @cm_info.implementation = 1
        myInfo << @cm_info
        get_children(sonChange, myInfo, indent+2)
      else
        @cm_info.implementation = 0
        myInfo << @cm_info
      end
    end
  end
end
