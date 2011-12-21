class CmTestsController < ApplicationController
  layout 'base'
     
  before_filter :find_cm_test, :only => [:show, :edit, :destroy, :history]
  before_filter :find_project, :only => [:new, :index, :copy]
  before_filter :authorize, :except => :history

  accept_key_auth :index, :show, :new, :edit, :destroy
  
  helper :journals
  include JournalsHelper
  helper :sort
  include SortHelper
  helper :watchers
  include WatchersHelper
  helper :cm_tests
  include CmTestsHelper
  helper :cm_common
  include CmCommonHelper
  include CmImportAssistant
  include CmDocCountersHelper

  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }
           
  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init [['id', 'asc'] , ['code', 'asc']]
    sort_update %w(id code name )

    #define filter capabilities
    conditions=prepare_filter()

    @total = CmTest.count(:conditions => conditions)

    if @cm_test_types.nil?
      @cm_test_types = CmTestType.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_test_types.insert(0, CmTestType.new(:name => "All", :id => 0))
    end
    if @cm_test_classifications.nil?
      @cm_test_classifications = CmTestClassification.find(:all, 
        :conditions => ['project_id in (?,?)', 0, @project.id])
      @cm_test_classifications.insert(0, CmTestClassification.new(:name => "All", :id => 0))
    end

    @cm_tests = CmTest.find(:all, :conditions => ['project_id=?', @project.id])
    @cm_test_pages, @cm_tests = paginate :cm_tests, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:assignee]

    if request.xml_http_request?
      render(:template => 'cm_tests/index.rhtml', :layout => !request.xhr?)
    end
  end
    
  def show
    prepare_combos()

    min_level = CmTestType.connection.select_value("select min(level) from cm_test_types where project_id=" +
        @project.id.to_s + " or project_id=0")
    if min_level.to_i < @cm_test.type.level
      @allow_relate_parent = true
    else
      @allow_relate_parent = false
    end

    max_level = CmTestType.connection.select_value("select max(level) from cm_test_types where project_id=" +
        @project.id.to_s + " or project_id=0")
    if max_level.to_i > @cm_test.type.level
      @allow_relate_children = true
    else
      @allow_relate_children = false
    end
  
    @journals = @cm_test.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    respond_to do |format|
      format.html { render :template => 'cm_tests/show.rhtml' }
#      format.cmdc { # Search for customized form... if any
        #custom_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
         # @project.id, "Project", @project.identifier + "_test_show_for_export.rhtml"])
#        if custom_file.nil?
#          html_page = render_to_string( :template => 'cm_tests/show_for_export.rhtml', :layout => false )
#        else
#          html_page = render_to_string( :file => Attachment.storage_path + "/" + custom_file.disk_filename )
#        end
#        send_data(html_page, :filename => "#{@project.name}-TE#{@cm_test.id}.html") }
    end
  end

  def edit
    if request.get?
      prepare_combos()
    end

    @notes = params[:notes]
    journal = @cm_test.init_journal(User.current, @notes)

    if params[:cm_test]
      attrs = params[:cm_test].dup
      @cm_test.attributes = attrs
    end

    if request.post?
      if @cm_test.valid?
        call_hook(:controller_cm_test_edit_before_save, {:params => params,
                  :cm_test => @cm_test, :journal => journal})
        if @cm_test.save
#          attachments = Attachment.attach_files(@cm_test, params[:attachments])
#          render_attachment_warning_if_needed(@cm_test)

          if !journal.new_record?
            # Only send notification if something was actually changed
            # flash[:notice] = l(:notice_successful_update)
#            @cm_test.errors.add_to_base(l(:notice_successful_update))
            flash[:notice] = @cm_test.errors.full_messages.to_sentence

            # Deliver email
            Mailer.deliver_cmdc_info(User.current, @project, @cm_test, 'cm_tests')
          end
          call_hook(:controller_cm_test_edit_after_save, { :params => params,
                    :cm_test => @cm_test, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_test})
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash.now[:error] = l(:notice_locking_conflict)
    # Remove the previously added attachments if issue was not updated
    #attachments.each(&:destroy)
  end
  
  def new
    prepare_combos()
    if request.get?
      if params[:cm_test]
        @cm_test = CmTest.new(params[:cm_test])
        @cm_test.code = ""
        @cm_test.project = @project
      else
        @cm_test = CmTest.new(:project => @project)
      end
      @number_of_tests_related = params[:number_of_tests] if params[:number_of_tests]
      @cm_test.author = User.current  
    end

    if request.post?
      @cm_test = CmTest.new(params[:cm_test])
      @cm_test.author = User.current
      @cm_test.project = @project

      prev_code = @cm_test.code
      @cm_test.counter_type=params[:counter_type].to_i
      
      @cm_test.watcher_user_ids=params[:cm_test]['watcher_user_ids']

      if @cm_test.save
        #When coming from Test father, create the relation at the same time
        #First save, to get the new id for the child Test
        @father_id=params[:working_data][:father_id]
        unless @father_id.blank?
          #Create relationship
          CmTestsTest.create(:cm_test_id => @father_id.to_i, :child_test_id => @cm_test.id,
            :created_on => Time.now, :author => User.current, :description => " ",
            :relation_type => 2, 
            :execution_order => (params[:working_data][:number_of_tests].to_i + 1) * 10)
        end
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_test.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_test.code
        end

        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_test, 'cm_tests')

        unless @father_id.blank?
          redirect_to :controller => 'cm_tests', :action => 'show', :id => @father_id.to_s
        else
          if params[:continue]
            redirect_to :action => 'new', :id => @project, :cm_test => params[:cm_test]
          else
            redirect_back_or_default({ :action => 'show', :id => @cm_test })
          end
        end
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error creating Test'
      end              
    end   
  end

  def destroy
      begin
        @cm_test.destroy
      rescue RuntimeError => e
        flash[:error]='Test not deleted: ' + e.message
      ensure
        redirect_to :action => 'index', :id => @project
      end
  end

  def history
    @cm_tr_history = CmTestCampaignsObject.find(:all,
      :conditions => ['cm_test_id = ? and cm_test_record_id <> ?', @cm_test, 0],
      :include => :cm_test_record)
  end

  def copy
    # create new test with the next free code
    prepare_combos()

    if request.get?
      @cm_test = CmTest.new(:project => @project)
      @copy_id = params[:copy_id]
    end
        
    if request.post?
      test_to_copy = CmTest.find(params[:working_data][:copy_id])
      @project = test_to_copy.project

      @new_test=test_to_copy.clone
      @new_test.code=params[:cm_test][:code]
      @new_test.name=params[:cm_test][:name]

      if @new_test.save
        # relate with new test ALL the first level child tests
        test_to_copy.cm_tests_tests.each do |ts|

          CmTestsTest.create(:cm_test_id => @new_test.id, :child_test_id => ts.id,
              :created_on => Time.now, :author => User.current, :description => ts.description,
              :relation_type => ts.relation_type, :execution_order => ts.execution_order)

        end
        flash[:notice] = "Test Copied successfully"
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @new_test
      else
        #Recover combos in case of error
        prepare_combos()
        flash[:error] = 'Error creating New Copied Test'
      end
    end

  end

  private
  def prepare_filter
    #First Condition, Project and subprojects
    columns, values = prepare_get_for_projects(CmTest, @project, params[:query_subp], params[:query])

    unless params[:query].blank?
      columns << " and #{CmTest.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmTest.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmTest.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmTest.table_name}.classification_id = ?"
      values << params[:query3].to_i
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos()
    if params[:test_level]
      @cm_test_types = CmTestType.find(:all, 
        :conditions => ["level = ? and project_id in (?,?)", params[:test_level].to_i, 0, @project.id])
      @coming_from_other_Test="Y"
      @father_id=params[:test_id]
    else
      @cm_test_types = CmTestType.find(:all, :conditions => ['project_id in (?,?)', 0, @project.id])
      @father_id=nil
    end

    if @cm_test_types.empty?
      render_error "There are no types defined for Tests!"
      return
    end

    @cm_test_classifications = CmTestClassification.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
    @cm_test_assignees = @project.assignable_users
    unless @cm_test_assignees
      render_error "There are no users assigned to the Project!"
      return
    end
    get_counter_types()

    #Get parent tests. Rel type has to be different from 3 (brothers)
    @parent_tests = CmTestsTest.find(:all, :conditions => ['child_test_id=?', @cm_test.id])
  end

  def get_counter_types
    @counter_types = CmDocCounter.my_project(@project.id).object_counters(change_cmdc_object_to_i('Test'))
    @counter_types.insert(0, CmDocCounter.new(:name => "<Use type acronym as counter type>"))
  end

  def find_cm_test 
    @cm_test = CmTest.find(params[:id], :include => [:project, :author])
    @project = @cm_test.project
    rescue ActiveRecord::RecordNotFound
    render_404    
  end  
   
  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
