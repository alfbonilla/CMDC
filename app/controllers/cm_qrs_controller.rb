class CmQrsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_qr, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize

  accept_rss_auth :show, :index, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :sort
  include SortHelper
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
    sort_update %w(id code type_id)

    #define filter capabilities
    if @cm_qr_types.nil?
      @cm_qr_types = CmQrType.find(:all)
      @cm_qr_types.insert(0, CmQrType.new(:name => "All", :id => 0))
    end
    conditions=prepare_filter()

    @total = CmQr.count(:conditions => conditions)
    
    @cm_qr_pages, @cm_qrs = paginate :cm_qrs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:type, :assignee, :author]

    if request.xml_http_request?
      render(:template => 'cm_qrs/index.rhtml', :layout => !request.xhr?)
    end
  end
          
  def show
    @cm_qrs = CmQr.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_qr_assignees = @project.assignable_users
    @cm_qr_types = CmQrType.find(:all)

    get_ncs()

    @journals = @cm_qr.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?              
  end

  def edit
    @cm_qrs = CmQr.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_qr_types = CmQrType.find(:all)
    @cm_qr_assignees = @project.assignable_users

    get_ncs()

    @notes = params[:notes]
    journal = @cm_qr.init_journal(User.current, @notes)
     
    if params[:cm_qr]
      attrs = params[:cm_qr].dup
      @cm_qr.attributes = attrs
    end
 
    if request.post?
      if @cm_qr.valid?
        save_nc()

        call_hook(:controller_cm_qr_edit_before_save, { :params => params, :cm_qr => @cm_qr, :journal => journal})
        if @cm_qr.save
          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)

            Mailer.deliver_cmdc_info(User.current, @project, @cm_qr, 'cm_qrs')
          end
          call_hook(:controller_cm_qr_edit_after_save, { :params => params, :cm_qr => @cm_qr, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_qr})
        end
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
   end
  
  def new
    # This option is just available coming from the object to review
    # So, x_id, x_name and x_type has to come completed
    if request.get?
      if params[:x_id].blank? or params[:x_name].blank? or params[:x_type].blank?
        render_error "Creation of QR misses object reviewed information"
        return
      end

      @cm_qr = CmQr.new
      @cm_qr.project = @project
      @cm_qr.author = User.current
      @cm_qr.x_id = params[:x_id]
      @cm_qr.x_name = params[:x_name]
      @cm_qr.x_type = params[:x_type]
    end

    @cm_qr_types = CmQrType.find(:all)
    @cm_qr_assignees = @project.assignable_users
    
    if request.post?
      @cm_qr = CmQr.new(params[:cm_qr])
      @cm_qr.project = @project
      @cm_qr.author = User.current
      prev_code = @cm_qr.code
      @cm_qr.watcher_user_ids=params[:cm_qr]['watcher_user_ids']

      if @cm_qr.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_qr.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_qr.code
        end

        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_qr, 'cm_qrs')
        
        redirect_back_or_default({ :action => 'show', :id => @cm_qr })
      else
        # reprepare environment
        @cm_qr_types = CmQrType.find(:all)
        @cm_qr_assignees = @project.assignable_users
        flash[:error] = 'Error saving board'
      end              
    end   
  end

  def destroy
    @cm_qr.destroy
    redirect_to :action => 'index', :id => @project
  end
 
  private

  def get_ncs
    # Ncs not closed and not related to any other QR
    @ncs = CmNc.open.no_qr_related.find(:all, :conditions => ['cm_ncs.project_id=?', @project.id])
    @ncs.insert(0, CmNc.new(:name => "related", :id => 0, :code => "None NC"))
  end

  def save_nc
    unless params[:cm_nc][:cm_nc].blank?
      nc_to_relate = CmNc.find(params[:cm_nc][:cm_nc])
      if nc_to_relate.nil?
        flash[:error] = 'Error relating NC. NC #' + params[:cm_nc][:cm_nc].to_s + ' not found!'
        return
      else
        nc_to_relate.cm_qr_id = @cm_qr.id
        nc_to_relate.save
      end
    end
  end

  def find_cm_qr
    @cm_qr = CmQr.find(params[:id], :include => [:project, :author, :type])
    @project = @cm_qr.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmQr, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmQr.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmQr.table_name}.type_id = ?"
      values << params[:query1].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end
end
