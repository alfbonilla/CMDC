class CmItemsItemsController < ApplicationController
  include CmCommonHelper

  accept_rss_auth :edit, :destroy    
 
  def new
    if request.get?
      @project_id = params[:project_id]
      @project = Project.find(@project_id)
      @rest_of_items = get_all_objects(CmItem, @project)

      if params[:porder_info_id].nil?
        @coming_from_purchase = "N"

        @cm_items_item = CmItemsItem.new
        @iitem_id = params[:id]
        @cm_items_item.cm_item_id = @iitem_id
        @item_to_relate = CmItem.find_by_id(@iitem_id)
        @rest_of_items.delete(@item_to_relate)
      else
        @coming_from_purchase = "Y"
        @cm_purchase_order_id = params[:porder_info_id].to_i
      end
    end
              
    if request.post?

      @coming_from_purchase = params[:working_data][:coming_from_purchase]

      if @coming_from_purchase == "N"
        @cm_items_item = CmItemsItem.new(params[:cm_items_item])
        @cm_items_item.author = User.current
        @cm_items_item.created_on = Time.now
      else
        @cm_purchase_order_id = params[:working_data][:cm_purchase_order_id].to_i
      end
      
      # Recover working data
      @project = Project.find(params[:working_data][:project_id])

      if @coming_from_purchase == "N"
        if @cm_items_item.save
          flash[:notice] = l(:notice_successful_create)
          redirect_to :controller => 'cm_items', :action => 'show', :project_id => @project_id,
            :id => @cm_items_item.cm_item_id
        else
          flash[:error] = 'Error saving relation between item and child item'
        end
      else
        redirect_to :controller => 'cm_po_details', :action => 'new',
          :id => @project, :item_id => params[:cm_items_item][:child_item_id],
          :po_id => @cm_purchase_order_id
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)

      # Restore fields in form
      @iitem_id = params[:id]
      @item_to_relate = CmItem.find_by_id(@iitem_id)
      @rest_of_items = CmItem.find(:all, :conditions => ['project_id=?', @project.id])
      @rest_of_items.delete(@item_to_relate)

      flash[:error] = 'There is a relation with Item ' + @cm_items_item.child_item_id.to_s + ' already created!'
  end

  def destroy
    @iitem_id = params[:iitem_id].to_i
    CmItemsItem.destroy(params[:relation_id])

    Journal.create(:journalized_id => @iitem_id, :journalized_type => 'CmItem', :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + params[:child_id])

    redirect_to :controller => 'cm_items', :action => 'show', :project_id => @project, :id => @iitem_id
  end
  
end
