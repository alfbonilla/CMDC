class CmDeliveriesController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_delivery, :only => [:show, :edit, :destroy, :meetings_review]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize, :except => :meetings_review

  accept_key_auth :show, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :attachments
  include AttachmentsHelper
  helper :sort
  include SortHelper
  helper :watchers
  include WatchersHelper
  include CmDeliveriesHelper
  helper :cm_common
  include CmCommonHelper
  
  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }
           
  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id code delivery_date from_company to_company)

    #define filter capabilities
    if @cm_companies.nil?
      @cm_companies = CmCompany.find(:all)
      @cm_companies.insert(0, CmCompany.new(:name => "All", :id => 0))
    end

    conditions=prepare_filter()

    @total = CmDelivery.count(:conditions => conditions)

    @cm_delivery_pages, @cm_deliveries = paginate :cm_deliveries, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:approver, :status, :source_company, :target_company]

    respond_to do |format|
      format.html { render(:template => 'cm_deliveries/index.rhtml', :layout => !request.xhr?) }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_delivery_index_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_deliveries/index_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-DeliveriessList.html")
      }
    end

  end
          
  def show
    prepare_combos()

    @cm_delivered_docs = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmDoc"],
      :joins => 'LEFT JOIN cm_docs ON cm_deliveries_objects.x_id=cm_docs.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_docs.code, cm_docs.name, cm_docs.external_doc_id,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @cm_delivered_items = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmItem"],
      :joins => 'LEFT JOIN cm_items ON cm_deliveries_objects.x_id=cm_items.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_items.code, cm_items.name, cm_items.product_tree_code,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @cm_closed_ncs = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmNcClosed"],
      :joins => 'LEFT JOIN cm_ncs ON cm_deliveries_objects.x_id=cm_ncs.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_ncs.code, cm_ncs.name,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @cm_delivered_ncs = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmNc"],
      :joins => 'LEFT JOIN cm_ncs ON cm_deliveries_objects.x_id=cm_ncs.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_ncs.code, cm_ncs.name,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @cm_delivered_changes = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmChange"],
      :joins => 'LEFT JOIN cm_changes ON cm_deliveries_objects.x_id=cm_changes.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_changes.code, cm_changes.name,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @cm_qrs = CmQr.find(:all, :conditions => [ "x_id = ? and x_type = ? and project_id = ?",
                                    @cm_delivery.id, "Delivery", @project.id])

    @journals = @cm_delivery.journals.find(:all, :include => [:user, :details],
            :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_deliveries/show.rhtml' }
      format.pdf  { send_data(cm_delivery_to_pdf(@cm_delivery), :type => 'application/pdf',
         :filename => "#{@cm_delivery.code}.pdf") }
#         :filename => "#{@project.identifier}-DN-#{@cm_delivery.code}.pdf") }
      format.cmdc { # Search for customized form... if any
        custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", @project.identifier + "_delivery_show_for_export.rhtml"])
        if custom_file.nil?
          html_page = render_to_string( :template => 'cm_deliveries/show_for_export.rhtml', :layout => false )
        else
          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
        end
        send_data(html_page, :filename => "#{@project.name}-Delivery#{@cm_req.id}.html") }
    end
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_delivery.init_journal(User.current, @notes)
     
    if params[:cm_delivery]
      attrs = params[:cm_delivery].dup
      @cm_delivery.attributes = attrs
    end
 
    if request.post?
      if @cm_delivery.valid?
        call_hook(:controller_cm_deliveries_edit_before_save, { :params => params,
            :cm_delivery => @cm_delivery, :journal => journal})
        if @cm_delivery.save
          attachments = Attachment.attach_files(@cm_delivery, params[:attachments])
          render_attachment_warning_if_needed(@cm_delivery)

          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)

            # Deliver email
            Mailer.deliver_cmdc_info(User.current, @project, @cm_delivery, 'cm_deliveries')
          end
          call_hook(:controller_cm_deliveries_edit_after_save, { :params => params,
                    :cm_delivery => @cm_delivery, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_delivery})
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
      @cm_delivery = CmDelivery.new(:project => @project)
      @cm_delivery.author = User.current

      prepare_combos()
    end
      
    if request.post?
      @cm_delivery = CmDelivery.new(params[:cm_delivery])
      @cm_delivery.author = User.current
      @cm_delivery.project = @project
      prev_code = @cm_delivery.code
      @cm_delivery.counter_type=params[:counter_type].to_i

      @cm_delivery.watcher_user_ids=params[:cm_delivery]['watcher_user_ids']

      if @cm_delivery.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_delivery.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_delivery.code
        end

        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_delivery, 'cm_deliveries')

        Attachment.attach_files(@cm_delivery, params[:attachments])
        render_attachment_warning_if_needed(@cm_delivery)

        redirect_back_or_default({ :action => 'show', :id => @cm_delivery })
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error saving non-conformance'
      end              
    end   
  end

  def destroy
    @cm_delivery.destroy
    redirect_to :action => 'index', :id => @project
  end

  def meetings_review
    # Search for those objects treated in meetings (NCs and Changes)
    # with same Target Version than the delivered
    @cmdc_objs = []
    cmdc = []
    c_count = 0

    @changes = CmChangesObject.find(:all, :conditions => [ "target_version_id = ? and x_type = ?",
        @cm_delivery.release_id, "CmBoard"])

    @changes.each do |chn|
      cmdc = [chn.cm_change.id.to_s, chn.cm_change.code, "CH", "NO"]
      @cmdc_objs[c_count]=cmdc
      c_count += 1
    end

    @changes_related = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND cm_deliveries_objects.x_type=?',
        @cm_delivery.id, "CmChange"],
      :joins => 'LEFT JOIN cm_changes ON cm_deliveries_objects.x_id=cm_changes.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_changes.code, cm_changes.name,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @changes_related.each do |chs|
      cmdc = [chs.x_id.to_s, chs.code, "CH", "NO"]
      pos = @cmdc_objs.index(cmdc)
      unless pos.nil?
        @cmdc_objs[pos][3] = "YES"
      end
    end

    @ncs = CmNcsObject.find(:all, :select => 'DISTINCT cm_nc_id',
        :conditions => [ "target_version_id = ? and x_type = ?",
        @cm_delivery.release_id, "CmBoard"], :order => 'cm_nc_id ASC')

    @ncs.each do |ncs|
      cmdc = [ncs.cm_nc.id.to_s, ncs.cm_nc.code, "NC", "NO"]
      @cmdc_objs[c_count]=cmdc
      c_count += 1
    end

    @ncs_meetings = c_count

    @ncs_solved = CmNc.find(:all, :conditions => [ "rlse_solved_id = ?", @cm_delivery.release_id])

    @ncs_solved.each do |ncs|
      cmdc = [ncs.id.to_s, ncs.code, "NC", "NO"]
      # Avoiding to repeat the same NCs
      pos = @cmdc_objs.index(cmdc)
      if pos.nil?
        @cmdc_objs[c_count]=cmdc
        c_count += 1
      end
    end

    # Exclude those records already related to the delivery
    @ncs_related = CmDeliveriesObject.find(:all,
      :conditions => ['cm_deliveries_objects.cm_delivery_id=? AND (cm_deliveries_objects.x_type=? OR cm_deliveries_objects.x_type=?)',
        @cm_delivery.id, "CmNc", "CmNcClosed"],
      :joins => 'LEFT JOIN cm_ncs ON cm_deliveries_objects.x_id=cm_ncs.id',
      :select => 'cm_deliveries_objects.id, cm_deliveries_objects.cm_delivery_id,
        cm_deliveries_objects.created_on, cm_ncs.code, cm_ncs.name,
        cm_deliveries_objects.rel_string, cm_deliveries_objects.x_id')

    @ncs_related.each do |ncs|
      cmdc = [ncs.x_id.to_s, ncs.code, "NC", "NO"]
      pos = @cmdc_objs.index(cmdc)
      unless pos.nil?
        @cmdc_objs[pos][3] = "YES"
      end
    end

    @revision_ok = true
    @cmdc_objs.each do |rev|
      if rev[3] == "NO"
        @revision_ok = false
        break
      end
    end

  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmDelivery, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmDelivery.table_name}.from_company = ?"
      values << params[:query].to_i
    end

    unless params[:query1].blank?
      columns << " and #{CmDelivery.table_name}.to_company = ?"
      values << params[:query1].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_companies = CmCompany.find(:all)
    @cm_delivery_approvers = @project.assignable_users
    @cm_delivery_statuses = CmDeliveryStatus.all(:all,
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @releases = Version.find(:all, :conditions => ['status = ? and project_id = ?', "open", @project.id])
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Delivery'))
  end

  def find_cm_delivery
    @cm_delivery = CmDelivery.find(params[:id], :include => [:project, :author, 
        :source_company, :target_company, :approver, :release, :status])
    @project = @cm_delivery.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
