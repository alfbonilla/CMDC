class CmTestCampaignsController < ApplicationController
  layout 'base'

  before_filter :find_cm_test_campaign, :only => [:show, :edit, :destroy]
  before_filter :find_project, :only => [:index, :new]
  before_filter :authorize, :except => :execution_list

  accept_key_auth :index, :show, :edit, :new, :destroy

  helper :journals
  include JournalsHelper
  helper :projects
  include ProjectsHelper
  helper :sort
  include SortHelper
  helper :cm_docs
  include CmDocsHelper
  helper :watchers
  include WatchersHelper
  helper :cm_test_campaigns
  include CmTestCampaignsHelper
  helper :cm_common
  include CmCommonHelper

  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }

  def index  
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id code name cm_test_campaign_group_id)

    #define filter capabilities
    conditions=prepare_filter()

    @total = CmTestCampaign.count(:conditions => conditions)
 
    @cm_test_campaign_pages, @cm_test_campaigns = paginate :cm_test_campaigns, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page,
                :include => [:assignee]

    if request.xml_http_request?
      render(:template => 'cm_test_campaigns/index.rhtml', :layout => !request.xhr?)
    end
  end


  def execution_list
    #:id => @project , :cm_test_record_id => iit.cm_test_record.id
    @cm_test_execution_list = CmTestRecord.find(:all, :conditions => ['code=?', params[:cm_test_record_code]])

    render :update do |page|
        page.replace_html  'test_records_list', :partial => 'execution_list',
                                    :object => @cm_test_execution_list
        page.visual_effect :highlight, 'test_records_list'
    end
  end


  def show
    prepare_combos()

    if request.get?
      @cm_test_record = CmTestRecord.new()
    end

    #When it's trying to create/update a TR from TK show.
    if request.post?

      @aux_params = params[:cm_test_record]
      @test_campaigns_object = CmTestCampaignsObject.find(:first,:conditions => ["id=?",@aux_params['cm_test_campaigns_object_id']])

      @cm_test_record = CmTestRecord.new()
      @cm_test_record.result = @aux_params['result']
      @cm_test_record.execution_evidences = @aux_params['execution_evidences']
      @cm_test_record.execution_date= @aux_params['execution_date']
      @cm_test_record.execution_log= @aux_params['execution_log']
      @cm_test_record.restrict_or_observe= @aux_params['restrict_or_observe']
      @cm_test_record.witnessed_by= @aux_params['witnessed_by']

      #There is not relation so the TR is new.
      if(@test_campaigns_object.cm_test_record_id == 0)
          @cm_test_record.code = @aux_params['code']
          @cm_test_record.project = @project
          @cm_test_record.author_id = User.current

         if @cm_test_record.save
            add_record_to_relation()
            flash[:notice] = l(:notice_successful_create)
         else
            flash[:error] = 'Error creating new Test record'
         end
      else
         #1º. Find the TR related to be updated.
         @cm_current_test_record = CmTestRecord.find(:first, :conditions =>["id=?",@test_campaigns_object.cm_test_record_id] )
         #The relation exits so there is only to update the test record (the code is not updated).
         params[:cm_test_record].delete("code")
         #These two field are not part of TR table, so they are deleted
         params[:cm_test_record].delete("cm_test_campaigns_object_id")
         params[:cm_test_record].delete("action")

         if @cm_current_test_record.update_attributes(params[:cm_test_record])
              flash[:notice] = l(:notice_successful_update)
         else
              flash[:error] = "Edit Record not performed!!"
         end
      end
         redirect_back_or_default({ :action => 'show',:controller => 'cm_test_campaigns', :id => params[:id]})
    end
 
    @cm_test_campaigns_object = CmTestCampaignsObject.find(:all, :conditions => ['cm_test_campaign_id=?', params[:id]], :order => "execution_order ASC" )
    @cm_test_campaigns_object
    if ! @cm_test_campaign.release_id == ""
      @release_id = Version.find(@cm_test_campaign.release_id)
    end
    @journals = @cm_test_campaign.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def edit

    prepare_combos()
    @notes = params[:notes]
    journal = @cm_test_campaign.init_journal(User.current, @notes)

    if params[:cm_test_campaign]
      attrs = params[:cm_test_campaign].dup
      @cm_test_campaign.attributes = attrs
    end
     
    if request.post?
      if @cm_test_campaign.valid?
        call_hook(:controller_cm_test_campaign_edit_before_save, { :params => params, :cm_test_campaign => @cm_test_campaign, :journal => journal})
        if @cm_test_campaign.save
          if !journal.new_record?
             # Only send notification if something was actually changed
             flash[:notice] = l(:notice_successful_update)
             Mailer.deliver_cmdc_info(User.current, @project, @cm_test_campaign, 'cm_test_campaigns')
          end
          call_hook(:controller_cm_test_campaign_edit_after_save, { :params => params, :cm_test_campaign => @cm_test_campaign, :journal => journal})
          redirect_back_or_default({:action => 'show', :id => @cm_test_campaign})
        else
          flash[:error] = "Edit not performed!!"
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
      if params[:cm_test_campaign]
        @cm_test_campaign = CmTestCampaign.new(params[:cm_test_campaign])
        @cm_test_campaign.code = ""
        @cm_test_campaign.project = @project
      else
        @cm_test_campaign = CmTestCampaign.new(:project => @project)
      end
      @cm_test_campaign.author = User.current
    end

    if request.post?
      @cm_test_campaign = CmTestCampaign.new(params[:cm_test_campaign])
      @cm_test_campaign.project = @project
      @cm_test_campaign.author = User.current
           
      prev_code = @cm_test_campaign.code
      if @cm_test_campaign.save
        flash[:notice] = l(:notice_successful_create)
        if prev_code != @cm_test_campaign.code
          flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_test_campaign.code
        end
        #Attachment.attach_files(@cm_test_campaign, params[:attachments])
        #render_attachment_warning_if_needed(@cm_test_campaign)
        Mailer.deliver_cmdc_info(User.current, @project, @cm_test_campaign, 'cm_test_campaigns')
        if params[:continue]
          redirect_to :action => 'new', :id => @project, :cm_test_campaign => params[:cm_test_campaign]
        else
          redirect_back_or_default({ :action => 'show', :id => @cm_test_campaign })
        end

        
      else
        flash[:error] = 'Error saving test_campaign'
      end
    end
  end

  def destroy
    begin
      @cm_test_campaign.destroy
      rescue RuntimeError => e
        flash[:error]='Test Campaign not deleted: ' + e.message
      ensure
        redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private
  def prepare_filter
    #First Condition, Project_id
    columns = "#{CmTestCampaign.table_name}.project_id = ?"
    values = [@project.id]

    unless params[:query].blank?
      columns << " and #{CmTestCampaign.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    unless params[:query1].blank?
      columns << " and #{CmTestCampaign.table_name}.name LIKE ?"
      values << "%#{params[:query1]}%"
    end

    unless params[:query2].blank?
      columns << " and #{CmTestCampaign.table_name}.type_id = ?"
      values << params[:query2].to_i
    end

    unless params[:query3].blank?
      columns << " and #{CmTestCampaign.table_name}.serial_number LIKE ?"
      values << "%#{params[:query3]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def find_cm_test_campaign
    @cm_test_campaign = CmTestCampaign.find(params[:id],
                :include => [:project, :cm_tests, :cm_test_records])
    @project = @cm_test_campaign.project
    rescue ActiveRecord::RecordNotFound
      render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end


 def add_record_to_relation
    
    @cm_test_campaign_object = CmTestCampaignsObject.find(:first,:conditions =>['id=?',@aux_params['cm_test_campaigns_object_id']])
    @relation_2_record = {'cm_test_record_id' => @cm_test_record.id}
    @cm_test_campaign_object.update_attributes(@relation_2_record)

  end

  def prepare_combos()
      @releases = Version.find(:all, :conditions => ['status = ? and project_id = ?', "open", @project.id])
      @cm_test_assignees = @project.assignable_users
      unless @cm_test_assignees
        render_error "There are no users assigned to the Project!"
        return
      end
  end
end