class CmPurchaseOrdersController < ApplicationController
  menu_item :new_cm_purchase_order, :only => :new

  before_filter :find_cm_purchase_order, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize

  accept_key_auth :show, :edit, :destroy  
  
  helper :journals
  include JournalsHelper
  helper :projects
  include ProjectsHelper   
  helper :sort
  include SortHelper
  include CmPurchaseOrdersHelper
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
    sort_update %w(id code title)

    #define filter capabilities
    conditions=prepare_filter()

    @total = CmPurchaseOrder.count(:conditions => conditions)

    @cm_purchase_order_pages, @cm_purchase_orders = paginate :cm_purchase_orders, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page, :include => [:supplier, :vendor]

    if request.xml_http_request?
      render(:template => 'cm_purchase_orders/index.rhtml', :layout => !request.xhr?)
    end
  end

  def show
    prepare_combos()

    @cm_qrs = CmQr.find(:all, :conditions => [ "x_id = ?", @cm_purchase_order.id])

    @journals = @cm_purchase_order.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_purchase_orders/show.rhtml' }
      format.pdf  { send_data(cm_po_to_pdf(@cm_purchase_order, params[:history]), :type => 'application/pdf', :history => params[:history],
                    :filename => "#{@project.identifier}-PO#{@cm_purchase_order.id}.pdf") }
    end
  end

  def edit
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_purchase_order.init_journal(User.current, @notes)

    if params[:cm_purchase_order]
      attrs = params[:cm_purchase_order].dup
      #attrs.delete_if {|k,v| !UPDATABLE_ATTRS_ON_TRANSITION.include?(k) } unless @edit_allowed
      #attrs.delete(:status_id) unless @allowed_statuses.detect {|s| s.id.to_s == attrs[:status_id].to_s}
      @cm_purchase_order.attributes = attrs
    end    

    if request.post?
      if @cm_purchase_order.valid?
        call_hook(:controller_cm_purchase_orders_edit_before_save, { :params => params, :cm_purchase_order => @cm_purchase_order, :journal => journal})
        if @cm_purchase_order.save
          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_purchase_orders_edit_after_save, { :params => params, :cm_purchase_order => @cm_purchase_order, :journal => journal})

          Mailer.deliver_cmdc_info(User.current, @project, @cm_purchase_order, 'cm_purchase_orders')

          redirect_back_or_default({:action => 'show', :id => @cm_purchase_order})
        else
          prepare_combos()
          flash[:error] = "Edit not performed!!"
        end
      end
    end    
    rescue ActiveRecord::StaleObjectError
      # Optimistic locking exception
      flash.now[:error] = l(:notice_locking_conflict)        
  end

  def new
    if request.get?
      @cm_purchase_order = CmPurchaseOrder.new
      @cm_purchase_order.project = @project
      @cm_purchase_order.author = User.current

      prepare_combos()
    end  
    
    if request.post?     
      @cm_purchase_order = CmPurchaseOrder.new(params[:cm_purchase_order])
      @cm_purchase_order.author = User.current
      @cm_purchase_order.project = @project
      prev_code = @cm_purchase_order.code
           
      if @cm_purchase_order.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_purchase_order.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_purchase_order.code
        end

        Mailer.deliver_cmdc_info(User.current, @project, @cm_purchase_order, 'cm_purchase_orders')

        redirect_back_or_default({ :action => 'show', :id => @cm_purchase_order })
      else
        prepare_combos()
        flash[:error] = 'Error saving purchase order'
      end              
    end       
  end

  def destroy
    @cm_purchase_order.destroy
    redirect_to :action => 'index', :id => @project
  end

  private
  def prepare_filter
    # porder.id = 1 is always NONE and is excluded from list treatment
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmPurchaseOrder, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmPurchaseOrder.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmPurchaseOrder.table_name}.title LIKE ?"
      values << "%#{params[:query1]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @suppliers = CmCompany.find(:all, :conditions => [ 'company_type = ? and project_id = ?',
                                                      "Supplier", @project.id ])
    @suppliers.insert(0, CmCompany.new(:name => "None", :id => 0))
    @vendors = CmCompany.find(:all, :conditions => [ 'company_type = ? and project_id = ?',
                                                      "Vendor", @project.id ])
    @vendors.insert(0, CmCompany.new(:name => "None", :id => 0))
  end

  def find_cm_purchase_order
    @cm_purchase_order = CmPurchaseOrder.find(params[:id],
                    :include => [:project, :supplier, :vendor, :author])
    @project = @cm_purchase_order.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
