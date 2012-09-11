class CmSmrsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_smr, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index]
  before_filter :authorize, :except => [:remove_relation]

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
    sort_update %w(id smr_code cm_nc_id)

    #define filter capabilities
    if params[:query].blank?
      @query = ""
      conditions = ["#{CmSmr.table_name}.project_id=?", @project.id]
    else
      conditions = ["#{CmSmr.table_name}.project_id=? and #{CmSmr.table_name}.smr_code LIKE ?", @project.id, "%#{params[:query]}%"]
    end

    @total = CmSmr.count(:conditions => conditions)

    @cm_smr_pages, @cm_smrs = paginate :cm_smrs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => :nonConformance

    if request.xml_http_request?
      render(:template => 'cm_smrs/index.rhtml', :layout => !request.xhr?)
    end
  end
          
  def show
    get_objects_to_relate()

    @journals = @cm_smr.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?              
  end

  def edit
    if request.get?
      get_objects_to_relate()
    end

    @notes = params[:notes]
    journal = @cm_smr.init_journal(User.current, @notes)

    if params[:cm_smr]
      attrs = params[:cm_smr].dup
      @cm_smr.attributes = attrs
    end

    if request.post?
      if @cm_smr.valid?
        call_hook(:controller_cm_smr_edit_before_save, { :params => params,
                                    :cm_smr => @cm_smr, :journal => journal})
        if @cm_smr.save
          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_cm_smr_edit_after_save, { :params => params,
                                      :cm_smr => @cm_smr, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_smr})
        else
          get_objects_to_relate()
          flash[:error] = 'Error saving SMR'
        end
      else
        get_objects_to_relate()
        flash[:error] = 'SMR not valid!!'
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash.now[:error] = l(:notice_locking_conflict)
  end
  
  def new
    if request.get?
      @cm_smr = CmSmr.new
      @cm_smr.project = @project
      @cm_smr.author = User.current

      if params[:nc_id].blank?
        @coming_from_NC = "N"
        @nc_id = 0
        get_objects_to_relate()
        if @cm_ncs_to_relate.blank? and @cm_changes_to_relate.blank?
          render_error "There are no objects (non-conformances or changes) to relate!"
          return
        end
      else
        @coming_from_NC = "Y"
        @ext_nc_id = params[:nc_id].to_i
        @ext_code = params[:code]
      end
    end
      
    if request.post?
      @cm_smr = CmSmr.new(params[:cm_smr])
      @cm_smr.project = @project
      @cm_smr.author = User.current
      prev_code = @cm_smr.smr_code

      # Recover working data
      @coming_from_NC = params[:working_data][:coming_from_NC]

      if @coming_from_NC == "Y"
        @ext_code = params[:working_data][:ext_code]
        @ext_nc_id = params[:working_data][:ext_nc_id]
        @cm_smr.cm_nc_id = params[:working_data][:ext_nc_id]
      end

      if @cm_smr.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_smr.smr_code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_smr.smr_code
        end
        if @coming_from_NC == "Y"
          redirect_to :controller => 'cm_ncs', :action => 'show', :id => @ext_nc_id
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_smr })
        end
      else
        if @coming_from_NC == "N"
          get_objects_to_relate()
        end
        flash[:error] = 'Error saving SMR'
      end              
    end   
  end
     
  def destroy
    @cm_smr.destroy
    redirect_to :action => 'index', :id => @project
  end

  def remove_relation
    #Retrieve smr to update
    @smr_id = params[:smr_id]
    @smr_to_update = CmSmr.find_by_id(@smr_id)

    if @smr_to_update.nil?
      flash[:error] = 'Error removing SMR relation.' + @smr_id.to_s + ' not found!'
    else
      #At the moment, SMR just can be related to NCS or CHANGES
      if params[:removed_type] == "CmNc"
        @smr_to_update.cm_nc_id = 0
      else
        @smr_to_update.cm_change_id = 0
      end

      @smr_to_update.save
    end

    redirect_to :controller => params[:caller_cont], :action => 'show',
      :project_id => params[:id], :id => params[:removed_id]
  end
 
  private

  def get_objects_to_relate
    @cm_ncs_to_relate = CmNc.find(:all,
      :conditions => ['cm_ncs.project_id=? AND cm_ncs_types.relate_smrs=true',  @project.id],
      :joins => 'LEFT JOIN cm_ncs_types ON cm_ncs.type_id=cm_ncs_types.id',
      :select => 'cm_ncs.id, cm_ncs.code, cm_ncs.name')

    @cm_changes_to_relate = CmChange.find(:all, :conditions => ['project_id=?', @project.id])
  end

  def find_cm_smr
    @cm_smr = CmSmr.find(params[:id], :include => [:project, :nonConformance, :author])
    @project = @cm_smr.project
   
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
