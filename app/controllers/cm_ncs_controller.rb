class CmNcsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_nc, :only => [:show, :edit, :destroy, :summary, 
          :remove_qr_relation, :new_issue]
  before_filter :find_project, :only => [:new, :index, :get_statistics]
  before_filter :authorize, :except => [:remove_qr_relation, :new_issue, :get_statistics]

  accept_key_auth :show, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :attachments
  include AttachmentsHelper
  helper :sort
  include SortHelper
  helper :cm_ncs_objects
  include CmNcsObjectsHelper
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
    sort_update %w(id code created_on assigned_to_id)

    #define filter capabilities
    conditions=prepare_filter()

    @total = CmNc.count(:conditions => conditions)

    @cm_nc_pages, @cm_ncs = paginate :cm_ncs, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:assignee, :status, :classification, :company]

    if request.xml_http_request?
      render(:template => 'cm_ncs/index.rhtml', :layout => !request.xhr?)
    end
  end
          
  def show
    prepare_combos()

    max_level = CmNcsType.connection.select_value("select max(level) from cm_ncs_types where project_id="+
        @project.id.to_s+" or project_id=0")
    if max_level.to_i > @cm_nc.type.level
      @allow_relate_children = true
    else
      @allow_relate_children = false
    end

    #@cm_ncs_issues = @cm_nc.issues
    
    @journals = @cm_nc.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?              
  end

  def edit
    if request.get?
      prepare_combos()
    end

    @notes = params[:notes]
    journal = @cm_nc.init_journal(User.current, @notes)
     
    if params[:cm_nc]
      attrs = params[:cm_nc].dup
      @cm_nc.attributes = attrs
    end
 
    if request.post?
      if @cm_nc.valid?
        call_hook(:controller_cm_nc_edit_before_save, { :params => params, :cm_nc => @cm_nc, :journal => journal})
        if @cm_nc.save
          attachments = Attachment.attach_files(@cm_nc, params[:attachments])
          render_attachment_warning_if_needed(@cm_nc)

          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)

            # Deliver email
            Mailer.deliver_cmdc_info(User.current, @project, @cm_nc, 'cm_ncs')
          end
          call_hook(:controller_cm_nc_edit_after_save, { :params => params, :cm_nc => @cm_nc, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_nc})
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
      if params[:cm_nc]
        @cm_nc = CmNc.new(params[:cm_nc])
        @cm_nc.code = ""
        @cm_nc.project = @project
      else
        # Control COPY option
        if params[:copy_nc_id]
          prepare_nc_with_copy_data()
        else
          @cm_nc = CmNc.new(:project => @project)

          if params[:caller_cont] == 'cm_test_records'
            @x_id = params[:x_id]
            @x_type = params[:x_type]
            test = CmTestRecord.find(@x_id)
            @originator = test.code
          end

          @caller_cont = "cm_ncs"
        end
      end
      prepare_combos()
    end
      
    if request.post?
      @cm_nc = CmNc.new(params[:cm_nc])
      @cm_nc.author = User.current
      @cm_nc.project = @project

      #Save info, just in case of error
      if params[:working_data][:x_type] == 'CmTestRecord'
        @x_id=params[:working_data][:x_id]
        @x_type=params[:working_data][:x_type]
      end

      #Ficticious versions added are set to nil
      @cm_nc.rlse_solved_id = nil if @cm_nc.rlse_solved_id == 0
      @cm_nc.rlse_verified_id = nil if @cm_nc.rlse_verified_id == 0

      prev_code = @cm_nc.code
      @cm_nc.counter_type = params[:counter_type].to_i

      @cm_nc.watcher_user_ids=params[:cm_nc]['watcher_user_ids']

      if @cm_nc.save
        #When coming from NC father, create the relation at the same time
        #First save, to get the new id for the child nc
        @father_id=params[:working_data][:father_id]
        unless @father_id.blank?
          #Create relationship
          CmNcsNc.create(:cm_nc_id => @father_id.to_i, :child_nc_id => @cm_nc.id,
            :created_on => Time.now, :author => User.current, :description => " ")
        end

        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_nc.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_nc.code
        end
        
        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_nc, 'cm_ncs')

        Attachment.attach_files(@cm_nc, params[:attachments])
        render_attachment_warning_if_needed(@cm_nc)

        #it's possible to created NC directly from cm_test_records (show view)
        if params[:working_data][:x_type] == 'CmTestRecord'
          @cm_ncs_object = CmNcsObject.new()
          @cm_ncs_object.cm_nc_id = @cm_nc.id
          @cm_ncs_object.x_id = params[:working_data][:x_id]
          @cm_ncs_object.x_type = params[:working_data][:x_type]
          @cm_ncs_object.created_on = Time.now
          @cm_ncs_object.author_id = User.current
          @cm_ncs_object.rel_string = "NC for T.Record"
          flash[:error] = 'Error creating non-conformance' unless @cm_ncs_object.save
          redirect_to :controller => 'cm_test_records', :action => 'show', :id => @cm_ncs_object.x_id
          return
        end

        unless @father_id.blank?
          redirect_to :controller => 'cm_ncs', :action => 'show', :id => @father_id.to_s
        else
          if params[:continue]
            redirect_to :action => 'new', :id => @project, :cm_nc => params[:cm_nc]
          else
            redirect_back_or_default({ :action => 'show', :id => @cm_nc })
          end
        end
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error creating non-conformance'
      end              
    end   
  end

  def summary
    @cm_ncs_boards = CmNcsObject.find(:all,
          :conditions => ['a.x_id=b.id and a.cm_nc_id=? and a.x_type=?', @cm_nc.id, "CmBoard"],
          :joins => 'a, cm_boards b',
          :select => 'b.cm_board_code, b.meeting_date, a.target_version_id, a.rel_string, a.rel_date, a.rel_bool, a.x_id')
  end

  def remove_qr_relation
    #Retrieve smr to update
    if @cm_nc.nil?
      flash[:error] = 'Error removing NC relation.' + params[:id].to_s + ' not found!'
    else
      @cm_nc.cm_qr_id = 0
      @cm_nc.save

      Journal.create(:journalized_id => params[:qr_id], :journalized_type => 'CmQr', :user_id => User.current.id,
               :notes => 'Deleted relation with NC ' + '"' + @cm_nc.name + '"(id: ' + @cm_nc.id.to_s + ')')
    end
    redirect_to :back
  end

  def destroy
    begin
      @cm_nc.destroy
    rescue RuntimeError => e
      flash[:error]='NC not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end


  def get_statistics

    if @cm_subsystems.nil?
      columns_s, values_s = prepare_get_for_projects(CmSubsystem, @project, nil, nil)
      conditions_s = [columns_s]
      values_s.each do |value|
        conditions_s << value
      end
      @cm_subsystems = CmSubsystem.find(:all, :conditions => conditions_s)
      @cm_subsystems.insert(0,CmSubsystem.new(:name => "All", :id=> 0))
    end

    if request.post?
      @codes_to_approve=params[:codes_to_approve]

      columns="project_id=?"
      values=[@project.id]

      unless @codes_to_approve.blank?
        columns << " AND code LIKE ?"
        values << "%#{@codes_to_approve}%"
      end

      unless params[:query_sub].blank?
        if params[:query_sub]
          columns << " AND subsystem_id = ?"
          values << params[:query_sub].to_i
        end
      end

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @ncs_status = CmNc.find(:all, :select => "status_id, count(*) AS count_by_status",
        :conditions => conditions, :group => "status_id", :include => :status)

      @ncs_company = CmNc.find(:all, :select => "company_id, count(*) AS count_by_company",
        :conditions => conditions, :group => "company_id", :include => :company)

      @ncs_status_type = CmNc.find(:all, :select => "status_id, type_id, count(*) AS count_by_status_type",
        :conditions => conditions, :group => "status_id, type_id", :order => "type_id, status_id",
        :include => [:status, :type])

      @ncs_status_type_subsystem = CmNc.find(:all,
        :select => "status_id, type_id, subsystem_id, count(*) AS count_by_subsystem",
        :conditions => conditions, :group => "status_id, type_id, subsystem_id",
        :order => "subsystem_id, type_id, status_id", :include => [:status, :type, :subsystem])

      @ncs_type_classification = CmNc.find(:all,
        :select => "type_id, status_id, classification_id, count(*) AS count_by_type_classification",
        :conditions => conditions, :group => "type_id, status_id, classification_id",
        :order => "type_id, status_id, classification_id", :include => [:type, :status, :classification])

      @ncs_type = CmNc.find(:all, :select => "type_id, count(*) AS count_by_type",
        :conditions => conditions, :group => "type_id", :include => :type)

      @ncs_classification = CmNc.find(:all, :select => "classification_id, count(*) AS count_by_classification",
        :conditions => conditions, :group => "classification_id", :include => :classification)

      @tot_ncs=0
      @ncs_status.each do |nc|
        @tot_ncs+=nc.count_by_status.to_i
      end
    end
  end


  private
  def prepare_filter
    # Prepare lists
    if @cm_ncs_types.nil?
      @cm_ncs_types = CmNcsType.find(:all, :conditions => ['project_id in (?, ?)', 0, @project.id])
      @cm_ncs_types.insert(0, CmNcsType.new(:name => "All", :id => 0))
    end
    if @cm_ncs_statuses.nil?
      @cm_ncs_statuses = CmNcsStatus.find(:all, :conditions => ['project_id in (?, ?)', 0, @project.id])
      @cm_ncs_statuses.insert(0, CmNcsStatus.new(:name => "All", :id => 0))
    end
    if @cm_ncs_classifications.nil?
      @cm_ncs_classifications = CmNcsClassification.find(:all, :conditions => ['project_id in (?, ?)', 0, @project.id])
      @cm_ncs_classifications.insert(0, CmNcsClassification.new(:name => "All", :id => 0))
    end

    if @cm_subsystems.nil?
      columns_s, values_s = prepare_get_for_projects(CmSubsystem, @project, nil, nil)
      conditions_s = [columns_s]
      values_s.each do |value|
        conditions_s << value
      end
      @cm_subsystems = CmSubsystem.find(:all, :conditions => conditions_s)
      @cm_subsystems.insert(0,CmSubsystem.new(:name => "All", :id=> 0))
    end
    
    #Get assignable users and add All and Not Assigned options
    assignees = @project.assignable_users
    tmp_assignees = {"Not Assigned" => -1}
    assignees.each do |assignee|
      tmp_assignees[assignee.name] = assignee.id
    end
    tmp_assignees["All"] = 0
    @cm_nc_assignees=tmp_assignees.sort_by { |k,v| v }
    #Get releases
    if @releases.nil?
      @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
      @releases.insert(0,Version.new(:name => "All", :id=> 0))
    end
    
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmNc, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmNc.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmNc.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmNc.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmNc.table_name}.status_id = ?"
      values << params[:query3].to_i
    end

    unless params[:query4].blank?
      columns << " and #{CmNc.table_name}.subsystem_id = ?"
      values << params[:query4].to_i
    end

    unless params[:query5].blank?
      columns << " and #{CmNc.table_name}.rlse_expected_id = ?"
      values << params[:query5].to_i
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query6]='' if params[:query6]=="0"

    unless params[:query6].blank?
      if params[:query6] == "-1"
        columns << " and #{CmNc.table_name}.assigned_to_id is NULL"
      else
        columns << " and #{CmNc.table_name}.assigned_to_id = ?"
        values << params[:query6].to_i
      end
    end

    unless params[:query7].blank?
      columns << " and #{CmNc.table_name}.classification_id = ?"
      values << params[:query7].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos()
      if @cm_nc.status.blank?
        @cm_nc.status = CmNcsStatus.default(@project.id)
        unless @cm_nc.status
          render_error "The NCs have no Status set as default!"
          return
        end
      end
      if @cm_nc.type.blank?
        @cm_nc.type = CmNcsType.default(@project.id)
        unless @cm_nc.type
          render_error "The NCs have no Type set as default!"
          return
        end
      end
      @cm_nc_statuses = CmNcsStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      if params[:nc_level]
        @cm_nc_types = CmNcsType.find(:all, 
          :conditions => ["level > ? and project_id in (?,?)", params[:nc_level].to_i, 0, @project.id])
        @coming_from_other_NC="Y"
        @father_id=params[:nc_id]
      else
        @cm_nc_types = CmNcsType.find(:all, 
          :conditions => ['project_id in (?,?)', 0, @project.id])
        @father_id=nil
      end
      @cm_nc_assignees = @project.assignable_users
      unless @cm_nc_assignees
        render_error "There are no users assigned to the Project!"
        return
      end
      @cm_nc_classifications = CmNcsClassification.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_nc_phases = CmNcsPhase.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_companies = CmCompany.find(:all)
      @suppliers = CmCompany.find(:all, :conditions => ['company_type=?', "Supplier"])
      @releases = Version.find(:all, :conditions => ["project_id=?", @project.id])
      unless @releases
        render_error "There are no Releases created for the Project!"
        return
      end
      #Add nil possibility for no relating at creation time a NC to any solved or verified release
      @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
      @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Non-Conformance'))
      @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))

      @deliveries = CmDeliveriesObject.find(:all,
          :conditions => ['cm_deliveries_objects.x_id=? AND (cm_deliveries_objects.x_type=? OR cm_deliveries_objects.x_type=?)',
          @cm_nc.id, "CmNc", "CmNcClosed"])

  end

  def find_cm_nc
# do not bring the asignee nor the releases... just to try
    @cm_nc = CmNc.find(params[:id], :include => [:project, :type, :author, :company, :status, :classification,
        :phase])
    @project = @cm_nc.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def prepare_nc_with_copy_data
    cm_nc_to_copy = CmNc.find(params[:copy_nc_id])
    @cm_nc = cm_nc_to_copy.clone
    @cm_nc.code =""
    @cm_nc.project = @project
  end

end
