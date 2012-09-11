class CmTestRecordsController < ApplicationController
  helper :cm_tests
  include CmTestsHelper
  helper :cm_common
  include CmCommonHelper
  helper :attachments
  include AttachmentsHelper
  helper :sort
  include SortHelper
  
  before_filter :find_project, :only => [:new, :index, :show_new_execution_form]
  before_filter :find_cm_test_record, :only => [:show, :edit, :destroy]
  before_filter :authorize, :except => [:show_new_execution_form, :show_execution_list]

  accept_rss_auth :index, :new, :edit, :destroy

  helper :journals
  include JournalsHelper

  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id code)

    #define filter capabilities
    conditions=prepare_filter()

    @total = CmTestRecord.count(:conditions => conditions)

    @cm_test_record_pages, @cm_test_records = paginate :cm_test_records,
        :order => sort_clause, :conditions => conditions, :per_page => items_per_page,
        :include => :assignee

    if request.xml_http_request?
      render(:template => 'cm_test_records/index.rhtml', :layout => !request.xhr?)
    end
  end

  def show_execution_list
    #:id => @project , :cm_test_record_id => iit.cm_test_record.id
    #'cm_test_record_code' => params[:cm_test_record_code]
    @cm_test_execution_list = CmTestRecord.find(:all, :conditions => ['code=?', params[:cm_test_record_code]])
    @data = {}
    @data[:cm_test_campaign] = params[:cm_test_campaign]
    @data[:cm_test_campaigns_object] = params[:cm_test_campaigns_object]
    @data[:cm_test_execution_list] = (@cm_test_execution_list)

    render :update do |page|
        page.replace_html  'test_records_list', :partial => 'execution_list',
                                    :object => @data
        page.visual_effect :highlight, 'test_records_list'
    end
  end

  def show_new_execution_form

    prepare_combos()
    
    @data = { 'cm_test_campaigns_object' => params[:cm_test_campaigns_object],
              'cm_test_campaign' => params[:cm_test_campaign],
              'project_id' => params[:project_id],
              'cm_test_record_code' => params[:cm_test_record_code ],
              'cm_test_record_assignees' => @cm_test_record_assignees,
              'caller_cont' => params[:caller_cont]}

    render :update do |page|
        page.replace_html  'test_records_list', :partial => 'new', :object => @data

        page.visual_effect :highlight, 'test_records_list'
     end
  end

  def new
    
    if params[:caller_cont] == 'cm_test_campaign'
       if request.post?
          @cm_test_record = CmTestRecord.new(params[:cm_test_record])
          @cm_test_campaigns_object = CmTestCampaignsObject.find(:first,
            :conditions => ["id=?", params[:working_data][:cm_test_campaigns_object]])
          @cm_test_record.cm_test_campaigns_object = @cm_test_campaigns_object
          @cm_test_record.project = @project
          @cm_test_record.author = User.current

          @cm_test_execution_list = CmTestRecord.find(:all,:conditions => ["code=?",@cm_test_record.code])
          @cm_test_record.execution_number = @cm_test_execution_list.size + 1

          prev_code = @cm_test_record.code
          if @cm_test_record.save
            flash[:notice] = l(:notice_successful_create)
            if prev_code != @cm_test_record.code
              flash[:notice] = l(:notice_successful_create) + "Code changed to next free value:" + @cm_test_record.code
            end

            Attachment.attach_files(@cm_test_record, params[:attachments])
            render_attachment_warning_if_needed(@cm_test_record)
          end

          #The relation (in CmTestCampaignObject) is always uploaded to the last record, in this way it's possible to obtain the last result easy.
          relation_2_record = {'cm_test_record_id' => @cm_test_record.id}
          @cm_test_campaigns_object.update_attributes(relation_2_record)

          #@cm_test_execution_list = CmTestRecord.find(:all, :conditions => ['code=?', @cm_test_record.code])
          # Add new record to the list
          @cm_test_execution_list << @cm_test_record
          @data = {}
          @data[:cm_test_campaign] = @cm_test_campaigns_object.cm_test_campaign
          @data[:cm_test_campaigns_object] = @cm_test_campaigns_object
          @data[:cm_test_execution_list] = (@cm_test_execution_list)
          @cm_test_campaigns_object = CmTestCampaignsObject.find(:all, 
            :conditions => ['cm_test_campaign_id=?', @cm_test_campaigns_object.cm_test_campaign],
            :order => "execution_order ASC" )

          render :update do |page|
                page.replace_html  'relations', :partial => 'cm_test_campaigns/relations',
                                          :object => @cm_test_campaigns_object

                page.replace_html  'test_records_list', :partial => 'execution_list',
                                          :object => @data

                page.visual_effect :highlight, 'test_records_list'
           end
       end
    end
  end
  
  def edit
    
    prepare_combos()

    @notes = params[:notes]
    journal = @cm_test_record.init_journal(User.current, @notes)
    @data = {}
   
    if request.get?
      @data = CmTestRecord.find(params[:id])
      @data[:cm_test_campaigns_object] =  params[:cm_test_campaigns_object] #This is only to avoid errors "compilation" , this value is useless in the edit record context.
      @data[:cm_test_campaign] =  params[:cm_test_campaign]
      @data[:cm_test_record_assignees] = @cm_test_record_assignees

      if params[:caller_cont] =='execution_list'
        @data[:caller_cont] = params[:caller_cont]
      else
        @data[:caller_cont] = 'cm_test_record'
      end

    end
    
    if request.post?
      if @cm_test_record.update_attributes(params[:cm_test_record])
        flash[:notice] = l(:notice_successful_update)

        Attachment.attach_files(@cm_test_record, params[:attachments])
        render_attachment_warning_if_needed(@cm_test_record)

        if params[:working_data][:caller_cont] == 'execution_list'
          redirect_to :controller => 'cm_test_campaigns', :action => 'show',:id => params[:working_data][:cm_test_campaign]
        else
          redirect_back_or_default({:action => 'show', :id => @cm_test_record})
        end
      else
        flash[:error] = "Edit not performed!!"
      end
    end

  end

  def show
    prepare_combos()

    @other_execs = CmTestRecord.find(:all, :conditions => ['project_id=? and code=?',
      @project, @cm_test_record.code])
    
    @data = CmTestRecord.find(params[:id])
    @data[:relation_id] =  0 #This is only to avoid errors "compilation" , this value is useless in the edit record context.
    @data[:cm_test_record_assignees] = @cm_test_record_assignees
    
    @journals = @cm_test_record.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end
  
  def destroy
    begin
    
        @last_execution_records = CmTestRecord.find(:last,:conditions => ['code=?',@cm_test_record.code])
        #Get the cm_test_campaign_object related with the Record before destroy it.
        @current_cm_test_campaigns_object_related = CmTestCampaignsObject.find(:first,:conditions => ['cm_test_record_id=?',@cm_test_record.id])
        #The element to delete is the last execution? (In this case is necessary to upload the link to CmTestCampaignObject.)
        
        if(@last_execution_records.id == @cm_test_record.id)
           @cm_test_record.destroy
           #Once delete it, get the successor.
           @current_execution_record = CmTestRecord.find(:last,:conditions => ['code=?',@last_execution_records.code])
           #If there was only one record, the relation_id with cm_test_record_id must be 0.
        
           if (@current_execution_record.nil?)
             @relation = {'cm_test_record_id' => 0}
           else
             @relation = {'cm_test_record_id' => @current_execution_record.id}
           end
           #Update the relation with the previous Test Record.
           @current_cm_test_campaigns_object_related.update_attributes(@relation)
        else
          @cm_test_record.destroy
        end
    rescue RuntimeError => e
      flash[:error]='Execution Record not deleted: ' + e.message
    ensure
      if params[:update].nil? #If is called from execution records list (in Campaign Show)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        @data = {}
        @cm_test_execution_list = CmTestRecord.find(:all, :conditions => ['code=?',@last_execution_records.code]) 
        @data[:cm_test_campaign] = params[:cm_test_campaign]
        @data[:cm_test_campaigns_object] = @current_cm_test_campaigns_object_related
        @data[:cm_test_execution_list] = @cm_test_execution_list = CmTestRecord.find(:all, :conditions => ['code=?',@last_execution_records.code])
        @cm_test_campaigns_object = CmTestCampaignsObject.find(:all, :conditions => ['cm_test_campaign_id=?', params[:cm_test_campaign]], :order => "execution_order ASC" )
         render :update do |page|
                page.replace_html  'relations', :partial => 'cm_test_campaigns/relations',
                                          :object => @cm_test_campaigns_object

                page.replace_html  'test_records_list', :partial => 'execution_list',
                                          :object => @data

                page.visual_effect :highlight, 'test_records_list'
        end  
    end
    end
  end

  private

  def find_cm_test_record
    @cm_test_record = CmTestRecord.find(params[:id], :include => [:project])
    @project = @cm_test_record.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    if params[:caller_cont] == "cm_test_campaign"
        @project = Project.find(:first,:conditions => ["identifier=?",params[:project_id]])
    else
      @project = Project.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

 def prepare_filter
    #First Condition, Project_id
    columns = "#{CmTestRecord.table_name}.project_id = ?"
    values = [@project.id]

    unless params[:query].blank?
      columns << " and #{CmTestRecord.table_name}.code LIKE ?"
      values << "%#{params[:query]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

  def prepare_combos()
    @cm_test_record_assignees = @project.assignable_users
#      logger.error("1º usuario = #{@cm_test_record_assignees.first}")
    unless @cm_test_record_assignees
      render_error "There are no users assigned to the Project!"
      return
    end
  end

end