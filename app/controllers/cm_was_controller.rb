class CmWasController < ApplicationController
  layout 'base'

  before_filter :find_cm_wa, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize

  accept_rss_auth :show, :new, :edit, :destroy

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
    sort_update %w(id cm_wa_code status)

    #define filter capabilities
    if @cm_wa_statuses.nil?
      @cm_wa_statuses = CmWa::WA_STATUSES.collect
      @cm_wa_statuses.insert(0, %w(All))
    end    

    conditions=prepare_filter()

    @total = CmWa.count(:conditions => conditions)

    @cm_wa_pages, @cm_was = paginate :cm_was, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:nonConformance, :author]

    if request.xml_http_request?
      render(:template => 'cm_was/index.rhtml', :layout => !request.xhr?)
    end
  end

  def show
    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open",@project.id])
    @cm_ncs = CmNc.find(:all, :conditions => ['project_id=?', @project.id])

    @journals = @cm_wa.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def edit
    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open",@project.id])
    if @cm_ncs.nil?
      @cm_ncs = CmNc.find(:all, :conditions => ['project_id=?', @project.id])
    end

    @notes = params[:notes]
    journal = @cm_wa.init_journal(User.current, @notes)

    if params[:cm_wa]
      attrs = params[:cm_wa].dup
      @cm_wa.attributes = attrs
    end

     if request.post?
       if @cm_wa.valid?
         call_hook(:controller_cm_was_edit_before_save, { :params => params, :cm_wa => @cm_wa, :journal => journal})
         if @cm_wa.save
           if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
           end
           call_hook(:controller_cm_was_edit_after_save, { :params => params, :cm_wa => @cm_wa, :journal => journal})
           redirect_back_or_default({:action => 'show', :id => @cm_wa})
         end
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
   end

  def new
    if request.get?
      @cm_wa = CmWa.new
      @cm_wa.project = @project
      @cm_wa.author = User.current
      @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open",@project.id])
      unless @releases
        render_error "There are no Releases created for the Project!"
        return
      end
      # Ncs not closed
      @cm_ncs = CmNc.open.my_project(@project.id)
      unless @cm_ncs
        render_error "There are no NCs not closed for the Project!"
        return
      end
    end

    if request.post?
      @cm_wa = CmWa.new(params[:cm_wa])
      @cm_wa.author = User.current
      @cm_wa.project = @project
      prev_code = @cm_wa.cm_wa_code

      #Ficticious version added is set to nil
      @cm_wa.rlse_removed_id = nil if @cm_wa.rlse_removed_id == 0

      if @cm_wa.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_wa.cm_wa_code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_wa.cm_wa_code
        end
        redirect_back_or_default({ :action => 'show', :id => @cm_wa })
      else
        @cm_ncs = CmNc.open.my_project(@project.id)
        @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open",@project.id])
        flash[:error] = 'Error saving work around'
      end
    end
  end

  def destroy
    @cm_wa.destroy
    redirect_to :action => 'index', :id => @project
  end

  private
  def prepare_filter
    if not params[:query1].blank?
       params[:query1] = "" if params[:query1] == "All"
    end

    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmWa, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmWa.table_name}.cm_wa_code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmWa.table_name}.status = ?"
      values << "%#{params[:query1]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end
    
  def find_cm_wa
    @cm_wa = CmWa.find(params[:id], :include => [:author, :rlse_removed, :nonConformance])
    @project = @cm_wa.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end