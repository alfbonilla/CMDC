class CmItemsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_item, :only => [:show, :edit, :destroy, :cidl]
  before_filter :find_project, :only => [:index, :new, :copy_item, :index_tree]
  before_filter :authorize, :except => [:remove_relation, :cidl]

  accept_rss_auth :index, :show, :edit, :new, :destroy, :remove_relation
  
  helper :journals
  include JournalsHelper
  helper :projects
  include ProjectsHelper   
  helper :sort
  include SortHelper
  helper :attachments
  include AttachmentsHelper
  include CmItemsHelper
  helper :cm_docs
  include CmDocsHelper
  helper :watchers
  include WatchersHelper
  helper :cm_common
  include CmCommonHelper
  include CmDocCountersHelper
  
  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }

  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id code name cm_item_group_id)
    
    #define filter capabilities
    conditions=prepare_filter()

    if @cm_item_types.nil?
      @cm_item_types = CmItemType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_item_types.insert(0, CmItemType.new(:name => "All", :id => 0))
    end

    @cm_critical_boolean = {'All' => 0, 'Critical' => 1, 'No Critical' => 2} if @cm_critical_boolean.nil?
    @cm_long_lead_boolean = {'All' => 0, 'Long Lead' => 1, 'No Long Lead' => 2} if @cm_long_lead_boolean.nil?

    @total = CmItem.count(:conditions => conditions)

    @cm_item_pages, @cm_items = paginate :cm_items, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:group, :status, :type]

    if request.xml_http_request?
      render(:template => 'cm_items/index.rhtml', :layout => !request.xhr?)
    end
  end

  def index_tree
    @cm_items = CmItem.find(:all, :conditions => ["project_id = ?", @project.id], :include => [:cm_child_items])

    #Prepare list
    @cm_info_items = []
    complete_list()

    @total = @cm_items.count

#    @cm_item_pages, @cm_info_items = paginate :cm_items, :order => nil,
#                :conditions => nil, :per_page => items_per_page

    if request.xml_http_request?
      render(:template => 'cm_items/index_tree.rhtml', :layout => !request.xhr?)
    end
  end

  def show
    prepare_combos()

    @journals = @cm_item.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
    
    respond_to do |format|
      format.html { render :template => 'cm_items/show.rhtml' }
      format.pdf  { send_data(cm_item_to_pdf(@cm_item, params[:history]), :type => 'application/pdf',
                    :filename => "#{@project.identifier}-#{@cm_item.id}.pdf") }
    end
  end

  def edit
    prepare_combos()

    unless params[:porder_info_id].nil?
      @coming_from_purchase = "Y"
      @cm_purchase_order_id = params[:porder_info_id].to_i
    end

    @notes = params[:notes]
    journal = @cm_item.init_journal(User.current, @notes)
     
    if params[:cm_item]
      attrs = params[:cm_item].dup
      @cm_item.attributes = attrs
    end
 
    if request.post?
      if @cm_item.valid?
        call_hook(:controller_cm_items_edit_before_save, { :params => params, :cm_item => @cm_item, :journal => journal})
        if @cm_item.save
          attachments = Attachment.attach_files(@cm_item, params[:attachments])
          render_attachment_warning_if_needed(@cm_item)
          if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_items_edit_after_save, { :params => params, :cm_item => @cm_item, :journal => journal})

          Mailer.deliver_cmdc_info(User.current, @project, @cm_item, 'cm_items')

          if params[:working_data][:coming_from_purchase] == "Y"
            redirect_to :controller => 'cm_purchase_orders', :action => 'show',
                  :id => @cm_item.cm_purchase_order_id
          else
            redirect_back_or_default({:action => 'show', :id => @cm_item})
          end
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
      if params[:cm_item]
        @cm_item = CmItem.new(params[:cm_item])
        @cm_item.code = ""
        @cm_item.project = @project
      else
        @cm_item = CmItem.new(:project => @project)
      end
      @cm_item.author = User.current
      default_status = CmItemStatus.default(@project.id)
      unless default_status
        render_error l(:error_no_default_cm_item_status)
        return
      end
      @cm_item.status = default_status

      if params[:porder_info_id].nil?
        @coming_from_purchase = "N"
      else
        @coming_from_purchase = "Y"
        @cm_purchase_order_id = params[:porder_info_id].to_i
        @cm_purchase_order_code = params[:porder_info_code].to_s
      end
    end
      
    if request.post?     
      @cm_item = CmItem.new(params[:cm_item])
      @cm_item.project = @project
      @cm_item.author = User.current
      prev_code = @cm_item.code
      @cm_item.counter_type=params[:counter_type].to_i

      # Recover working data and let it prepare in case of error
      @coming_from_purchase = params[:working_data][:coming_from_purchase]
      if @coming_from_purchase == "Y"
        # @cm_item.cm_purchase_order_id = params[:working_data][:w_cm_purchase_order_id]
        @w_cm_purchase_order_id=params[:working_data][:w_cm_purchase_order_id]
        @w_cm_purchase_order_code=params[:working_data][:w_cm_purchase_order_code]
      end

      if @cm_item.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_item.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_item.code
        end
        Attachment.attach_files(@cm_item, params[:attachments])
        render_attachment_warning_if_needed(@cm_item)

        Mailer.deliver_cmdc_info(User.current, @project, @cm_item, 'cm_items')

        if @coming_from_purchase == "Y"
          redirect_to :controller => 'cm_po_details', :action => 'new',
              :id => @project, :item_id => @cm_item.id, :po_id => @w_cm_purchase_order_id
        else
          if params[:continue]
            redirect_to :action => 'new', :id => @project, :cm_item => params[:cm_item]
          else
            redirect_back_or_default({ :action => 'show', :id => @cm_item })
          end
        end
      else
        flash[:error] = 'Error creating Item'
      end              
    end   
  end
     
  def destroy
    begin
      @cm_item.destroy
    rescue RuntimeError => e
      flash[:error]='Item not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end

def copy_item
    if params[:working_data]
      @cm_item = CmItem.find(:first,
        :conditions => ["id = ?", params[:working_data][:copy_item_id].to_i], :include => [:cm_child_items])
    else
      @cm_item = CmItem.find(:first,
        :conditions => ["id = ?", params[:copy_item_id].to_i], :include => [:cm_child_items])
    end

    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Item'))

    @cm_items = []
    @cm_items << @cm_item
    @cm_info_items = []

    # Show form with hierarchy of items
    if request.get?
      # TODO: prepare list of counters!!!
      #Prepare list
      complete_list()
      @total = @cm_info_items.count
    end

  # TODO: handle errors!!
    if request.post?
      #Prepare list and Create new items
      @first_new_item = nil
      @counter_type = params[:counter_type].to_i

      #True parameter for creating new items
      complete_list(true, params[:suffix_to_add])

      #Now get the list of new items
      @cm_items = []
      @cm_items << @first_new_item
      @cm_info_items = []

      complete_list(false)

      @total = @cm_info_items.count
      
      flash[:notice]='Item copied successfully'
    end

  end


  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmItem, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmItem.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmItem.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmItem.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmItem.table_name}.serial_number LIKE ?"
      values << "%#{params[:query3]}%"
    end

    params[:query4]='' if params[:query4]=="0"

    unless params[:query4].blank?
      columns << " and #{CmItem.table_name}.critical_item = ?"
      if params[:query4]=="1"
        values << true
      else
        values << false
      end
    end

    params[:query5]='' if params[:query5]=="0"

    unless params[:query5].blank?
      columns << " and #{CmItem.table_name}.long_lead_item = ?"
      if params[:query5]=="1"
        values << true
      else
        values << false
      end
    end    

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos
    @cm_item_statuses = CmItemStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_item_categories = CmItemCategory.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_item_groups = CmItemGroup.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_item_types = CmItemType.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_item_classifications = CmItemClassification.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Item'))

    @deliveries = CmDeliveriesObject.find(:all,
        :conditions => ['cm_deliveries_objects.x_id=? AND cm_deliveries_objects.x_type=?',
        @cm_item.id, "CmItem"])

    @cm_qrs = CmQr.find(:all, :conditions => [ "x_id = ? and x_type = ? and project_id = ?",
        @cm_item.id, "InventoryItem", @project.id])

    @cm_po_details = CmPoDetail.find(:all, :conditions => ["cm_item_id = ?",@cm_item.id])
  end

  def find_cm_item
    @cm_item = CmItem.find(params[:id], :include => [:project, :status, :author,
        :group, :category, :classification, :type])
    @project = @cm_item.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
   
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def get_children (myItem, myInfo, indent, create=false, suffix="", myId=0)
    #Parms description:
    #myItem => item to explore
    #myInfo => collection of items to display in form
    #indent => indentation
    #create => true for creating new items
    #suffix => when creating, add this suffix to the new item name
    #myId   => when creating, the id of new item copied

    myindent = indent + 2
    myItem.cm_child_items.each do |childitem|
      @cm_info = CmItem.new
      @cm_info.quantity = myItem.id

      sonItem = CmItem.find(childitem.child_item_id, :include => [:cm_child_items])

      @cm_info.id=sonItem.id; @cm_info.code=sonItem.code; @cm_info.name=sonItem.name
      @cm_info.cm_item_group_id=sonItem.cm_item_group_id; @cm_info.status_id=sonItem.status_id
      @cm_info.available_qty=myindent

      if create
        code_to_assign=get_code_from_controller(@counter_type, sonItem.type.name, sonItem.type.acronym)

        begin
          new_item=copy_this_item(sonItem, suffix, code_to_assign)
        rescue RuntimeError => e
          flash[:error]="Copy of " + sonItem.code + " not created: " + e.message
          return
        end

        logger.error(">> Created item " + new_item.code + ", id:" + new_item.id.to_s)
        
        begin
          relate_these_items(myId, new_item, childitem.relation_type)
        rescue RuntimeError => e
          flash[:error]="New Relation for " + new_item.code + " not created: " + e.message
          return
        end
        new_item_id=new_item.id
      else
        new_item_id=0
      end

      if sonItem.cm_child_items.any?
        @cm_info.configuration_item = 1
        myInfo << @cm_info
        get_children(sonItem, myInfo, indent+2, create, suffix, new_item_id)
      else
        @cm_info.configuration_item = 0
        myInfo << @cm_info
      end
    end
  end

  def complete_list (create=false, suffix="")
    @cm_items.each do |iitem|
      @cm_info = CmItem.new

      #Cm_Item fields are used for managing the new list, replacing original info (not shown in the list)
      #with special values neccessary for seeing the structure as a tree:
      #   - configuration_item USED FOR indicating if the item has children
      #   - quantity USED FOR saving the parent item id
      #   - available_qty USED FOR saving the indentation value
      #If id is not already included
      if( !(@cm_info_items.detect {|pid| pid.id == iitem.id }))
        @cm_info.id=iitem.id; @cm_info.code=iitem.code; @cm_info.name=iitem.name;
        @cm_info.cm_item_group_id=iitem.cm_item_group_id; @cm_info.status_id=iitem.status_id
        @cm_info.quantity=0; @cm_info.available_qty=0

        if create
          code_to_assign=get_code_from_controller(@counter_type,
              iitem.type.name, iitem.type.acronym)

          begin
            @first_new_item=copy_this_item(iitem, suffix, code_to_assign)
          rescue RuntimeError => e
            flash[:error]="Copy of " + iitem.code + " not created: " + e.message
            return
          end
          new_item_id=@first_new_item.id

          logger.error("FIRST COPIED ITEM: Code =>" + @first_new_item.code +
             ", id => " + @first_new_item.id.to_s + ".")
        else
          new_item_id=0
        end
        
        if iitem.cm_child_items.any?
          @cm_info.configuration_item = 1
          @cm_info_items << @cm_info

          get_children(iitem, @cm_info_items, 0, create, suffix, new_item_id)
        else
          @cm_info.configuration_item = 0
          @cm_info_items << @cm_info
        end
      end
    end
  end

  def copy_this_item(item_to_copy, suffix, code)
    cm_new_item = item_to_copy.clone
    # Prepare local data with data from last_version (if any)
    cm_new_item.code = code
    cm_new_item.name = cm_new_item.name + suffix
    cm_new_item.serial_number = ""
    cm_new_item.created_on = Time.now
    cm_new_item.author_id = User.current
#    cm_new_item.project = @project
    unless cm_new_item.save
      raise "New item not created!!"
    end

    cm_new_item
  end

  def relate_these_items(father_item_id, child_item, relation_type)
    #Parms description:
    # father_item_id => id for the parent of the relation
    # child_item     => child item
    # relation_type  => relation type
    unless CmItemsItem.create(:cm_item_id => father_item_id, :child_item_id => child_item.id,
      :author_id => User.current, :relation_type => relation_type)
      raise "New item-item relation not created!!"
    end
  end

end
