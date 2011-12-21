class CmRisksController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_risk, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:new, :index, :refresh_priority, :progress_report]
  before_filter :authorize, :except => [:progress_report]

  accept_key_auth :show, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :attachments
  include AttachmentsHelper
  helper :sort
  include SortHelper
  include CmRisksHelper
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
    sort_update %w(id code priority_ranking risk_exposure)

    #define filter capabilities
    conditions=prepare_filter()

    if @cm_risks_statuses.nil?
      @cm_risks_statuses = CmRiskStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_risks_statuses.insert(0, CmRiskStatus.new(:name => "All", :id => 0))
    end    

    @cm_risks_impacts = {'All' => 0, change_impact_to_s(-1) => -1, change_impact_to_s(1) => 1,
      change_impact_to_s(2) => 2, change_impact_to_s(3) => 3, change_impact_to_s(4) => 4,
      change_impact_to_s(5) => 5, change_impact_to_s(99) => 99} if @cm_risks_impacts.nil?

    @total = CmRisk.count(:conditions => conditions)

    @cm_risk_pages, @cm_risks = paginate :cm_risks, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:assignee, :status]

    if request.xml_http_request?
      render(:template => 'cm_risks/index.rhtml', :layout => !request.xhr?)
    end
  end
          
  def show
    prepare_combos()

    @journals = @cm_risk.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?              
  end

  def edit
    if request.get?
      prepare_combos()
    end

    @notes = params[:notes]
    journal = @cm_risk.init_journal(User.current, @notes)
     
    if params[:cm_risk]
      attrs = params[:cm_risk].dup
      @cm_risk.attributes = attrs
    end
 
    if request.post?
      if @cm_risk.valid?
        call_hook(:controller_cm_risk_edit_before_save, { :params => params, :cm_risk => @cm_risk, :journal => journal})
        if @cm_risk.save

          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)

            # Deliver email
            Mailer.deliver_cmdc_info(User.current, @project, @cm_risk, 'cm_risks')

          end
          call_hook(:controller_cm_risk_edit_after_save, { :params => params, :cm_risk => @cm_risk, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_risk})
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    prepare_combos()
    flash.now[:error] = l(:notice_locking_conflict)
  end
  
  def new 
    if request.get?
      @cm_risk = CmRisk.new(:project => @project)
      @cm_risk.detection_date = Date.today
      @cm_risk.author = User.current

      prepare_combos()
    end
      
    if request.post?
      @cm_risk = CmRisk.new(params[:cm_risk])
      @cm_risk.author = User.current
      @cm_risk.project = @project
      prev_code = @cm_risk.code
      @cm_risk.watcher_user_ids=params[:cm_risk]['watcher_user_ids']

      if @cm_risk.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_risk.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_risk.code
        end

        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_risk, 'cm_risks')

        redirect_back_or_default({ :action => 'show', :id => @cm_risk })
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error saving risk'
      end              
    end   
  end

  def destroy
    begin
      @cm_risk.destroy
    rescue RuntimeError => e
      flash[:error]='Risk not deleted: ' + e.message
    ensure
      redirect_to :action => 'index', :id => @project
    end
  end

  def refresh_priority(called_from_internal=false)
    updated=false

    @risks = CmRisk.find(:all, :conditions => ['project_id=?', @project.id],
                          :include => [:project, :status])

    @risks.each do |risk|

      unless risk.closed?
        new_priority = calculate_priority(risk.impact_ini_date,
                          risk.impact_end_date, risk.risk_exposure)
      end

      if new_priority != risk.priority_ranking
        CmRisk.update(risk.id, :priority_ranking => new_priority)
        updated=true
      end
    end
    unless called_from_internal
      if updated
        flash[:notice]='Priorities updated successfully!'
      else
        flash[:notice]='All Priorities were up to date'
      end
      redirect_back_or_default({ :action => 'index', :id => @project })
    end
  end

  def progress_report
    if request.post?
      @in_post=true

      #new risks in the period (init_date > ending_date)
      @init_date=params[:init_date]
      @ending_date=params[:ending_date]

      @new_risks = CmRisk.find(:all,
        :conditions => ['project_id=? and detection_date between ? and ?',
          @project, @init_date, @ending_date])

      #mitigated risks in the period => risks with issues created in the period
      @mitigated_risks = CmRisk.find_by_sql("SELECT a.id, a.code, a.name, c.subject, c.created_on
        FROM cm_risks AS a INNER JOIN cm_objects_issues AS b ON b.cm_object_id = a.id
        INNER JOIN issues AS c ON c.id = b.issue_id
        WHERE a.project_id = #{@project.id} AND b.cm_object_type = 'CmRisk' AND
        c.created_on between '#{@init_date}' AND '#{@ending_date}'")

      #avoided risks => closed risks!
      @avoided_risks = CmRisk.find(:all,
        :conditions => ['project_id=? and closing_date between ? and ?',
          @project, @init_date, @ending_date])

      @risks_status = CmRisk.find(:all, :select => "status_id, count(*) AS count_by_status",
        :conditions => ['project_id in (?,?)', 0, @project], :group => "status_id")

      #summary table creation
      #refresh priority values
      refresh_priority(true)

      @out_of_date_risks = []
      @closed_risks = []

      @impact_table=[["", "", "", "", ""],["", "", "", "", ""],["", "", "", "", ""],
        ["", "", "", "", ""],["", "", "", "", ""]]
#      impact_it=["", "", "", "", ""]
      @priority_table=[["", "", "", "", ""],["", "", "", "", ""],["", "", "", "", ""],
        ["", "", "", "", ""],["", "", "", "", ""]]
#      priority_it=["", "", "", "", ""]
      risks = CmRisk.find(:all, :conditions => ['project_id=?', @project])

      risks.each do |r|
        # Matured and closed risks are not shown
        this_day=Date.today
        if r.status.is_closed?
          @closed_risks << r.code + " (" + r.name + ")"
          next
        end
        if r.priority_ranking == 99 or r.impact == -1
          if r.priority_ranking == 99 and not r.status.is_closed?
            @out_of_date_risks << r.code + " (" + r.name + ")"
          end
          next
        end
        next if this_day > r.impact_end_date

        # Impact vs Probability table
        case r.impact
        when 1
          table_impact = 4
        when 2
          table_impact = 3
        when 3
          table_impact = 2
        when 4
          table_impact = 1
        when 5
          table_impact = 0
        end
                
        case r.probability
        when 0..20
          table_probability = 0
        when 21..40
          table_probability = 1
        when 41..60
          table_probability = 2
        when 61..80
          table_probability = 3
        when 81..100
          table_probability = 4
        end

        case r.risk_exposure
        when 1
          table_exposure = 4
        when 2
          table_exposure = 3
        when 3
          table_exposure = 2
        when 4
          table_exposure = 1
        when 5
          table_exposure = 0
        end

        if this_day < r.impact_ini_date
          days_to_impact=r.impact_ini_date - this_day
        else
          days_to_impact=0
        end

        case days_to_impact
        when 0..7
          table_time=4
        when 8..30
          table_time=3
        when 31..90
          table_time=2
        when 91..180
          table_time=1
        else
          table_time=0
        end

#        impact_it[table_probability]=impact_it[table_probability] + "<br>" + r.code
#        priority_it[table_time]=priority_it[table_time] + "<br>" + r.code

        @impact_table[table_impact][table_probability] =
          @impact_table[table_impact][table_probability] + "<br>" + r.code
        @priority_table[table_exposure][table_time] =
          @priority_table[table_exposure][table_time] + "<br>" + r.code
      end
    end
  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmRisk, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmRisk.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmRisk.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmRisk.table_name}.status_id = ?"
      values << params[:query2]
    end

    #select_tag options used for this parm send a 0 if selected "All"
    params[:query3]='' if params[:query3]=="0"

    unless params[:query3].blank?
      columns << " and #{CmRisk.table_name}.impact = ?"
      values << params[:query3].to_i
    end
    
    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos()
      if @cm_risk.status.blank?
        @cm_risk.status = CmRiskStatus.default(@project.id)
        unless @cm_risk.status
          render_error "The Risks have no Status set as default!"
          return
        end
      end
      @cm_risk_statuses = CmRiskStatus.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_risk_assignees = @project.assignable_users
      unless @cm_risk_assignees
        render_error "There are no users assigned to the Project!"
        return
      end
      if @cm_risk.type.blank?
        @cm_risk.type = CmRiskType.default(@project.id)
        unless @cm_risk.type
          render_error "The Risks have no Type set as default!"
          return
        end
      end
      @cm_risk_types = CmRiskType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def find_cm_risk
    @cm_risk = CmRisk.find(params[:id], :include => [:project, :author, 
                            :status, :type, :assignee])
    @project = @cm_risk.project
  rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
