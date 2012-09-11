class CmDeliveriesObjectsController < ApplicationController
  include CmCommonHelper

  before_filter :find_project, :only => [:new_docs, :new_items, :new_ncs, :new_changes]
  before_filter :find_cm_deliveries_object, :only => [:edit]

  accept_rss_auth :edit, :destroy

  def new_docs
    if request.get?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:cm_delivery_id]
      @x_type = params[:x_type]
      # Search for those x_type in projects hierarchy that have not been already related to the delivery
      columns, values = prepare_get_for_projects(CmDoc, @project, nil, nil)
      columns << " AND id NOT IN (SELECT x_id FROM cm_deliveries_objects WHERE cm_delivery_id=? AND x_type=?)"
      values << @cm_delivery_id
      values << @x_type

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @cm_deliveries_objects = CmDoc.find(:all, :conditions => conditions, :order => "code ASC")
    end

    if request.post?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:working_data][:cm_delivery_id]

      #foreach checked doc, create a new relation
      all_saved = true
      relation_time = Time.now
      @myHash = params[:ids]

      if @myHash.nil?
        flash[:notice] = 'No documents selected!'

        redirect_to :back, @params=params
        
      else
        @myHash.each do |doc_id|
          cm_doc=CmDoc.find(doc_id)
          @cm_deliveries_object = CmDeliveriesObject.new
          @cm_deliveries_object.cm_delivery_id = @cm_delivery_id
          @cm_deliveries_object.x_id = cm_doc.id
          @cm_deliveries_object.x_type = "CmDoc"
          @cm_deliveries_object.rel_string = cm_doc.last_version.version
          @cm_deliveries_object.rel_string_2 = cm_doc.last_version.physical_location
          @cm_deliveries_object.author = User.current
          @cm_deliveries_object.created_on = relation_time

          if @cm_deliveries_object.save
            flash[:notice] = 'Document related successfully: ' + cm_doc.code
          else
            all_saved = false
            flash[:error] = 'Error saving relations with document ' + cm_doc.code
          end
        end

        flash[:notice] = 'Documents related with the delivery successfully!' if all_saved
        
        redirect_to :controller => 'cm_deliveries',
          :action => 'show', :id => @cm_deliveries_object.cm_delivery_id
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)
    flash[:error] = 'There is a relation with document ' + @cm_deliveries_object.x_id + ' already created!'
  end

  def new_items
    if request.get?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:cm_delivery_id]
      @x_type = params[:x_type]

      # Search for those x_type in projects hierarchy that have not been already related to the delivery
      columns, values = prepare_get_for_projects(CmItem, @project, nil, nil)
      columns << " AND id NOT IN (SELECT x_id FROM cm_deliveries_objects WHERE cm_delivery_id=? AND x_type=?)"
      values << @cm_delivery_id
      values << @x_type

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @cm_deliveries_objects = CmItem.find(:all, :conditions => conditions, :order => "code ASC")
    end

    if request.post?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:working_data][:cm_delivery_id]

      #foreach checked doc, create a new relation
      all_saved = true
      relation_time = Time.now
      @myHash = params[:ids]

      if @myHash.nil?
        flash[:notice] = 'No items selected!'
      else
        @myHash.each do |item_id|
          cm_item=CmItem.find(item_id)
          @cm_deliveries_object = CmDeliveriesObject.new
          @cm_deliveries_object.cm_delivery_id = @cm_delivery_id
          @cm_deliveries_object.x_id = cm_item.id
          @cm_deliveries_object.x_type = "CmItem"
          @cm_deliveries_object.rel_string = cm_item.version
          @cm_deliveries_object.rel_string_2 = cm_item.physical_location
          @cm_deliveries_object.author = User.current
          @cm_deliveries_object.created_on = relation_time

          if @cm_deliveries_object.save
            flash[:notice] = 'Item related successfully: ' + cm_item.code
          else
            all_saved = false
            flash[:error] = 'Error saving relations with item ' + cm_item.code
          end
        end

        flash[:notice] = 'Items related with the delivery successfully!' if all_saved

        redirect_to :controller => 'cm_deliveries',
          :action => 'show', :id => @cm_deliveries_object.cm_delivery_id
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)
    flash[:error] = 'There is a relation with item ' + @cm_deliveries_object.x_id + ' already created!'
  end

  def new_ncs
    if request.get?
      # Input parms: the delivery_id
      if params[:working_data]
        @cm_delivery_id = params[:working_data][:cm_delivery_id]
        @x_type = params[:working_data][:x_type]
        @rlse_id = params[:working_data][:rlse_id]
      else
        @cm_delivery_id = params[:cm_delivery_id]
        @x_type = params[:x_type]
        @rlse_id = params[:rlse_id]
      end

      if @cm_subsystems.nil?
        @cm_subsystems = CmSubsystem.find(:all, :conditions => ['project_id=?', @project.id])
        @cm_subsystems.insert(0,CmSubsystem.new(:name => "All", :id=> 0))
      end
      
#      # Search for those x_type that have not been already related to the delivery
#      @cm_deliveries_objects = CmNc.find(:all,
#      :conditions => ['project_id = ? AND id not in (SELECT x_id FROM cm_deliveries_objects WHERE cm_delivery_id=? AND x_type=?)',
#      @project.id, @cm_delivery_id, @x_type])

      # Search for those x_type in projects hierarchy that have not been already related to the delivery
      columns, values = prepare_get_for_projects(CmNc, @project, nil, nil)
      columns << " AND cm_ncs.id NOT IN (SELECT x_id FROM cm_deliveries_objects WHERE cm_delivery_id=? AND x_type=?)"
      values << @cm_delivery_id
      values << @x_type

      # Common filters
      unless params[:query_code].blank?
        columns << " AND code LIKE ?"
        values << "%#{params[:query_code]}%"
      end

      unless params[:query_sub].blank?
        if params[:query_sub]
          columns << " AND subsystem_id = ?"
          values << params[:query_sub].to_i
        end
      end

      # Get NCs alive or closed
      columns << " AND #{CmNcsStatus.table_name}.is_closed = ?"
      if @x_type == "CmNcClosed"
        values << true

        unless params[:query_close].blank?
          columns << " AND closing_date >= ?"
          start_date = Date.strptime(params[:query_close].to_s, '%d/%m/%Y')
          values << start_date
        end
      else
        values << false
      
        unless params[:query_exp].blank?
          if params[:query_exp]
            columns << " AND rlse_expected_id = ?"
            values << @rlse_id.to_i
          end
        end
      end

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @cm_deliveries_objects = CmNc.find(:all, :conditions => conditions,
        :include => :status, :order => "code ASC")
    end

    if request.post?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:working_data][:cm_delivery_id]
      @x_type = params[:working_data][:x_type]

      #foreach checked doc, create a new relation
      all_saved = true
      relation_time = Time.now
      @myHash = params[:ids]

      if @myHash.nil?
        flash[:notice] = 'No items selected!'
      else
        @myHash.each do |nc_id|
          cm_nc=CmNc.find(nc_id)
          @cm_deliveries_object = CmDeliveriesObject.new
          @cm_deliveries_object.cm_delivery_id = @cm_delivery_id
          @cm_deliveries_object.x_id = cm_nc.id
          @cm_deliveries_object.x_type = @x_type
          if @x_type == "CmNc"
            @cm_deliveries_object.rel_string = cm_nc.status.name
          else
            @cm_deliveries_object.rel_string = cm_nc.closing_date
          end
          @cm_deliveries_object.rel_string_2 = cm_nc.assignee.login
          @cm_deliveries_object.author = User.current
          @cm_deliveries_object.created_on = relation_time

          if @cm_deliveries_object.save
            flash[:notice] = 'Nc related successfully: ' + cm_nc.code
          else
            all_saved = false
            flash[:error] = 'Error saving relations with item ' + cm_nc.code
          end
        end

        flash[:notice] = 'NCs related with the delivery successfully!' if all_saved

        redirect_to :controller => 'cm_deliveries',
          :action => 'show', :id => @cm_deliveries_object.cm_delivery_id
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)
    flash[:error] = 'There is a relation with NC ' + @cm_deliveries_object.x_id + ' already created!'
  end

  def new_changes
    if request.get?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:cm_delivery_id]
      @x_type = params[:x_type]

      # Search for those x_type in projects hierarchy that have not been already related to the delivery
      columns, values = prepare_get_for_projects(CmChange, @project, nil, nil)
      columns << " AND id NOT IN (SELECT x_id FROM cm_deliveries_objects WHERE cm_delivery_id=? AND x_type=?)"
      values << @cm_delivery_id
      values << @x_type

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @cm_deliveries_objects = CmChange.find(:all, :conditions => conditions, :order => "code ASC")
    end

    if request.post?
      # Input parms: the delivery_id
      @cm_delivery_id = params[:working_data][:cm_delivery_id]

      #foreach checked change, create a new relation
      all_saved = true
      relation_time = Time.now
      @myHash = params[:ids]

      if @myHash.nil?
        flash[:notice] = 'No changes selected!'
      else
        @myHash.each do |ch_id|
          cm_change=CmChange.find(ch_id)
          @cm_deliveries_object = CmDeliveriesObject.new
          @cm_deliveries_object.cm_delivery_id = @cm_delivery_id
          @cm_deliveries_object.x_id = cm_change.id
          @cm_deliveries_object.x_type = "CmChange"
          if cm_change.applicable_version.blank?
            @cm_deliveries_object.rel_string = "N/A"
          else
            @cm_deliveries_object.rel_string = cm_change.applicable_version
          end
          @cm_deliveries_object.rel_string_2 = cm_change.author.name
          @cm_deliveries_object.rel_date = cm_change.due_date
          @cm_deliveries_object.author = User.current
          @cm_deliveries_object.created_on = relation_time

          if @cm_deliveries_object.save
            flash[:notice] = 'Change related successfully: ' + cm_change.code
          else
            all_saved = false
            flash[:error] = 'Error saving relations with Change ' + cm_change.code
          end
        end

        flash[:notice] = 'Changes related with the delivery successfully!' if all_saved

        redirect_to :controller => 'cm_deliveries',
          :action => 'show', :id => @cm_deliveries_object.cm_delivery_id
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)
    flash[:error] = 'There is a relation with change ' + @cm_deliveries_object.x_id + ' already created!'
  end

  def edit
    @cm_code = params[:cm_code]

    if params[:cm_deliveries_object]
      attrs = params[:cm_deliveries_object].dup
      @cm_deliveries_object.attributes = attrs
    end

    if request.post?
      @cm_code = params[:working_data][:cm_code]

      if @cm_deliveries_object.valid?
        if @cm_deliveries_object.save
          # Only send notification if something was actually changed
          flash[:notice] = l(:notice_successful_update)

          Journal.create(:journalized_id => @cm_deliveries_object.cm_delivery_id, 
            :journalized_type => "CmDelivery", :user_id => User.current.id,
            :notes => 'Edited relation with ' + @cm_code)

          redirect_to :controller => 'cm_deliveries',
            :action => 'show', :id => @cm_deliveries_object.cm_delivery_id
        else
          flash[:error] = 'Error saving relation with Document'
        end
       end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    delivery_id = params[:cm_delivery_id]
    CmDeliveriesObject.destroy(params[:relation_id])
    params[:cm_code].nil? ? code = "Unknown" : code = params[:cm_code]

    Journal.create(:journalized_id => delivery_id,
      :journalized_type => "CmDelivery", :user_id => User.current.id,
      :notes => 'Deleted relation with ' + code)

    redirect_to :controller => "cm_deliveries", :action => 'show', :id => delivery_id
  end

  private
  def find_cm_deliveries_object
    @cm_deliveries_object = CmDeliveriesObject.find(params[:id], :include => :author)
    case @cm_deliveries_object.x_type
    when "CmDoc"
      obj=CmDoc.find(@cm_deliveries_object.x_id)
    when "CmItem"
      obj=CmItem.find(@cm_deliveries_object.x_id)
    when "CmNc", "CmNcClosed"
      obj=CmNc.find(@cm_deliveries_object.x_id)
    when "CmChange"
      obj=CmChange.find(@cm_deliveries_object.x_id)
    end
    @project = obj.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
