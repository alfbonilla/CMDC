class CmItemsObjectsController < ApplicationController
  include CmCommonHelper

  before_filter :find_project, :only => [:relate_items]

  accept_key_auth :edit, :destroy

  def new
    if request.get?
      get_item_to_relate("parms")

      prepare_combos()

      @cm_items_object = CmItemsObject.new
      @cm_items_object.x_id = @x_id
      @cm_items_object.x_type = @x_type

      if @x_type == "CmDoc"
        @cm_items_object.rel_string = "Applicable Version: " + 
          @object_to_relate.applicable_version + " at relation time"
      end
    end
              
    if request.post? 
      @cm_items_object = CmItemsObject.new(params[:cm_items_object])
      @cm_items_object.author = User.current
      @cm_items_object.created_on = Time.now

      #Restore working_data, just in case of error
      @caller_cont = params[:working_data][:caller_cont]
      @project_id = params[:working_data][:project_id]
        
      if @cm_items_object.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => params[:working_data][:caller_cont],
          :action => 'show', :id => @cm_items_object.x_id
      else
        get_item_to_relate("ownparms")
        prepare_combos()
        flash[:error] = 'Error saving relation with Item'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    get_item_to_relate("ownparms")
    prepare_combos()

    flash[:error] = 'There is a relation with Item ' + @cm_items_object.cm_item.code + ' already created!'
  end

 def relate_items
    # Initially JUST for test campaigns
    if request.get?
      # Input parms: the x_id + x_type => save them in working for POST process
      @x_type = params[:x_type]
      @x_id = params[:x_id]
      @caller_cont = params[:caller_cont]

      # Search for those x_type that have not been already related to the x_id object
      case @x_type
      when "CmTestCampaign"
        @cm_items_objects = CmItem.find(:all,
            :conditions => ["project_id = ? AND id not in (SELECT cm_item_id FROM \
                cm_items_objects WHERE x_id=? AND x_type=?)",
                @project.id, @x_id, @x_type], :include => [:status])
      end
    end

    if request.post?
      # Input parms: the delivery_id
      @x_id = params[:working_data][:x_id]
      @x_type = params[:working_data][:x_type]
      @caller_cont = params[:working_data][:caller_cont]

      #foreach checked id, create a new relation
      all_saved = true
      relation_time = Time.now
      @myHash = params[:ids]
      message_ok=""
      message_error=""

      if @myHash.nil?
        flash[:notice] = 'No items selected!'
      else
        @myHash.each do |it|
          cm_item=CmItem.find(it)
          case @x_type
          when "CmTestCampaign"
            cm_items_object = CmItemsObject.new
            cm_items_object.cm_item_id = cm_item.id
            cm_items_object.x_id = @x_id
            cm_items_object.x_type = @x_type
            cm_items_object.rel_string = cm_item.version
            cm_items_object.rel_string_2 = cm_item.physical_location
            cm_items_object.author = User.current
            cm_items_object.created_on = relation_time

            if cm_items_object.save
              message_ok = message_ok + cm_item.code + " - "
            else
              all_saved = false
              message_error = message_error + cm_item.code + " - "
            end
          end

        end

        if all_saved
          flash[:notice] = message_ok + 'Items related successfully'
        else
          message_error = message_error + 'Items NOT related'
          message_error = message_error + '. ANYWAY, ' + message_ok + 'Items related OK' unless message_ok.empty?
          flash[:error] = message_error
        end

        redirect_to :controller => @caller_cont, :action => 'show', :id => @x_id
      end
    end
  end

  def edit
    @cm_items_object = CmItemsObject.find(params[:id])
    get_item_to_relate("object")
    
    if request.get?
      @code = params[:code]
      prepare_combos()
    end

    if params[:cm_items_object]
      attrs = params[:cm_items_object].dup
      @cm_items_object.attributes = attrs
    end

    if request.post?
      # Recover working data
      @code = params[:working_data][:item_code]

      if @cm_items_object.valid?
        if @cm_items_object.save
          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update)

          Journal.create(:journalized_id => @cm_items_object.x_id, :journalized_type => @x_type,
                :user_id => User.current.id,:notes => 'Edited relation with ' + @code)

          if @caller_cont == "cm_items"
            redirect_id = @cm_items_object.cm_item_id
          else
            redirect_id = @cm_items_object.x_id
          end

          redirect_to :controller => @caller_cont,
                    :action => 'show', :id => redirect_id
        else
          get_item_to_relate("ownparms")
          prepare_combos()
          flash[:error] = 'Error saving relation with Item'
        end
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    relation=CmItemsObject.find_by_id(params[:relation_id])
    
    params[:code].nil? ? code = "Unknown" : code = params[:code]

    Journal.create(:journalized_id => relation.x_id, :journalized_type => relation.x_type,
      :user_id => User.current.id, :notes => 'Deleted relation with ' + code)

    if @caller_cont == "cm_items"
      redirect_id = relation.cm_item_id
    else
      redirect_id = relation.x_id
    end

    relation.destroy

    redirect_to :controller => params[:caller_cont], :action => 'show', :id => redirect_id
  end

  private

  def get_item_to_relate(from_where)
    #Pass parms to instance vbles and recover item to relate based on x_type
    case from_where
    when "parms"
      @x_id = params[:x_id]
      @x_type = params[:x_type]
      @caller_cont = params[:caller_cont]
    when "ownparms"
      @x_id = params[:cm_items_object][:x_id]
      @x_type = params[:cm_items_object][:x_type]
      @caller_cont = params[:working_data][:caller_cont]
    when "object"
      @x_id = @cm_items_object.x_id
      @x_type = @cm_items_object.x_type
      @caller_cont = params[:working_data][:caller_cont] if request.post?
      @caller_cont = params[:caller_cont] if request.get?
    end

    case @x_type
      when "CmDoc"
        @object_to_relate = CmDoc.find(@x_id)
        @object_name = @object_to_relate.code
    end
    @project = Project.find(@object_to_relate.project_id)
    @project_id = @project.id
  end

  def prepare_combos
    @items = get_all_objects(CmItem, @project)
    @releases = Version.find(:all, :conditions => ['status=? and project_id=?',"open", @project.id])
    @issue_types = @project.trackers.find(:all)
    @issue_projects = @project.children.visible
    @issue_projects.insert(0, @project)
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
