class CmDocCountersController < ApplicationController

  before_filter :find_cm_doc_counter, :only => [:edit, :destroy, :new_doc]
  before_filter :find_project, :only => [:new, :index, :new_doc_by_type]
  before_filter :authorize, :except => :new_doc_by_type

  accept_rss_auth :index, :destroy, :new_doc  

  helper :sort
  include SortHelper
  helper :cm_common
  include CmCommonHelper
  include CmDocCountersHelper

  def index
    params[:per_page] ? items_per_page=params[:per_page].to_i : items_per_page=25

    #define sort capabilities
    sort_init(['id', 'asc'])
    sort_update %w(id name)

    conditions=prepare_filter()
    @total = CmDocCounter.count(:conditions => conditions)

    @cm_doc_counter_pages, @cm_doc_counters = paginate :cm_doc_counters, :order => sort_clause,
                :conditions => conditions, :per_page => items_per_page

    respond_to do |format|
      format.html { render(:template => 'cm_doc_counters/index.rhtml', :layout => !request.xhr?) }
    end
  end

  def new  
    if request.get?
      @cm_doc_counter = CmDocCounter.new
      @cm_doc_counter.project = @project
    end
    
    if request.post?
      @cm_doc_counter = CmDocCounter.new(params[:cm_doc_counter])
      @cm_doc_counter.cmdc_object=params[:cmdc_object] if params[:cmdc_object]
      @cm_doc_counter.project = @project
      
      if @cm_doc_counter.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new code'
      end
    end
  end

  def destroy
    @cm_doc_counter.destroy
    redirect_back_or_default({ :action => 'index', :id => @project})
  end

  def edit
    if params[:cm_doc_counter]
      attrs = params[:cm_doc_counter].dup
      @cm_doc_counter.attributes = attrs
    end
    
    if request.post?
     @cm_doc_counter.cmdc_object=params[:cmdc_object] if params[:cmdc_object]
     if @cm_doc_counter.valid?
       if @cm_doc_counter.save
           flash[:notice] = l(:notice_successful_update)
           redirect_back_or_default({:action => 'index', :id => @project})
       end
     end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash.now[:error] = l(:notice_locking_conflict)
  end

  def new_doc
    @cm_version = "N/A"
    @cm_subsystem = "N/A"
    @cm_type = "N/A"
    @cm_approval_level = "N/A"
    @coming_from_new_doc = true

    if request.post?
      #increase counter
      @cm_doc_counter.counter = @cm_doc_counter.counter + @cm_doc_counter.increment_by

      if @cm_doc_counter.save
        if @cm_doc_counter.format.blank?
          flash[:notice] = 'Code counter incremented. No new name. Pattern (counter or doc type) is empty'
        else
          #Format name
          new_formatted_name = format_name(@cm_doc_counter.format)
          flash[:notice] = 'Code counter incremented. New code: '+ new_formatted_name
        end
      else
        flash[:error] = 'Error increading counter for code ' + @cm_doc_counter.to_s
      end
      redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  def new_doc_by_type
    # Always update field id="new_code_generated"
    come_back=false
    @cm_version = "N/A"
    @cm_subsystem = "N/A"
    @cm_type = "N/A"
    @cm_approval_level = "N/A"
    
    cm_counter_id = params[:counter_type].to_i unless  params[:counter_type].nil?

    if params[:caller_cont].nil?
      caller_controller = params[:working_data][:caller_cont]
    else
      caller_controller = params[:caller_cont]
    end

    # Special actions for some cmdc objects
    case caller_controller
    when 'cm_docs'
      #Get name for received type
      object_type = CmDocType.find(params[:cm_doc][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Document Type '+ params[:cm_doc][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
      @cm_subsystem = CmSubsystem.find(params[:cm_doc][:subsystem_id].to_i) unless params[:cm_doc][:subsystem_id].blank?
      @cm_version = params[:cm_doc][:l_version] unless params[:cm_doc][:l_version].blank?
      @cm_approval_level = params[:cm_doc][:approval_level] unless params[:cm_doc][:approval_level].blank?
    when 'cm_items'
      #Get name for received type
      object_type = CmItemType.find(params[:cm_item][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Item Type '+ params[:cm_item][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
    when 'cm_boards'
      #Get name for received type
      object_type = CmBoardType.find(params[:cm_board][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Meeting Type '+ params[:cm_board][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
    when 'cm_ncs'
      #Get name for received type
      object_type = CmNcsType.find(params[:cm_nc][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Non-conformance Type '+ params[:cm_nc][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
      @cm_subsystem = CmSubsystem.find(params[:cm_nc][:subsystem_id].to_i) unless params[:cm_nc][:subsystem_id].blank?
    when 'cm_changes'
      #Get name for received type
      object_type = CmChangeType.find(params[:cm_change][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Change Type '+ params[:cm_change][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
    when 'cm_reqs'
      #Get name for received type
      object_type = CmReqsType.find(params[:cm_req][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for TE Type '+ params[:cm_req][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
      @cm_subsystem = CmSubsystem.find(params[:cm_req][:subsystem_id].to_i) unless params[:cm_req][:subsystem_id].blank?
    when 'cm_tests'
      #Get name for received type
      object_type = CmTestType.find(params[:cm_test][:type_id].to_i)
      if object_type.blank?
        message_error = 'Data not found for Test Type '+ params[:cm_test][:type_id].to_s
        come_back=true
      else
        @cm_type = object_type.acronym
      end
#    else
#      message_error = 'Dont know who is calling: ' + caller_controller
#      come_back=true
    end

    if object_type and object_type.acronym.empty?
      message_error = 'Type Acronym is empty!'
      come_back=true
    end


    unless come_back
      if cm_counter_id.blank?
        # Called from CMDC objects without counter selection
        @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['cmdc_object=? and project_id=?',
            params[:cmdc_object].to_i, @project.id])
      else
        if cm_counter_id == 0
          # Selected option for searching counter by type name
          @cm_doc_counter = CmDocCounter.find(:first,
          :conditions => ['name=? and project_id=?',
            object_type.name, @project.id])
        else
          # Selected option for searching counter by counter id
          @cm_doc_counter = CmDocCounter.find(cm_counter_id)
        end
      end
      
      if @cm_doc_counter.blank?
        if cm_counter_id.blank?
          new_formatted_name = change_cmdc_object_to_s(params[:cmdc_object].to_i) +
                              ' counter not found'
        else
          new_formatted_name = object_type.name + ' counter not found'
        end
      else
        new_formatted_name = assign_code()
      end

      respond_to do |format|
        format.js do
          render(:update) {|page|
            page << "updateCode(\"#{new_formatted_name}\")" }
        end
      end
    else
      respond_to do |format|
        format.js do
          render(:update) {|page|
          page << "updateCode(\"#{message_error}\")" }
        end
      end
    end
  end

  private

  def assign_code
    @project = @cm_doc_counter.project
    @cm_doc_counter.counter = @cm_doc_counter.counter + @cm_doc_counter.increment_by

    if @cm_doc_counter.format.blank?
      'Code counter incremented. No new name. <br /> Pattern is empty'
    else
      format_name(@cm_doc_counter.format)
    end
  end

  def find_cm_doc_counter
    @cm_doc_counter = CmDocCounter.find(params[:id], :include => :project)
    @project = @cm_doc_counter.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end

  def prepare_filter
    #First Condition, Project_id
    columns = "#{CmDocCounter.table_name}.project_id = ?"
    values = [@project.id]

    unless params[:query].blank?
      columns << " and #{CmDocCounter.table_name}.name LIKE ?"
      values << "%#{params[:query]}%"
    end

    conditions = [columns]
    values.each do |value|
      conditions << value
    end
    return conditions
  end

end