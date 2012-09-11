class CmPoDetailsController < ApplicationController

  before_filter :find_cm_po_detail, :only => [:edit]

  accept_rss_auth :edit, :destroy

  def new
    if request.get?
      @cm_item_id = params[:item_id]
      @cm_purchase_order_id = params[:po_id]
      @project = Project.find(params[:id])

      @cm_po_detail = CmPoDetail.new
      @cm_po_detail.cm_item_id = @cm_item_id
      @cm_po_detail.cm_purchase_order_id = @cm_purchase_order_id
    end
              
    if request.post? 
      @cm_po_detail = CmPoDetail.new(params[:cm_po_detail])
      @cm_po_detail.author = User.current

      # Recover working data
      @cm_po_detail.cm_item_id = params[:working_data][:cm_item_id]
      @cm_po_detail.cm_purchase_order_id = params[:working_data][:cm_purchase_order_id]
      @project = Project.find(params[:working_data][:project_id])

      @cm_po_detail.project = @project

      if @cm_po_detail.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => 'cm_purchase_orders', :action => 'show',
          :id => @cm_po_detail.cm_purchase_order_id
      else
        flash[:error] = 'Error saving relation details between purchase order and item'
      end
    end
  
  rescue ActiveRecord::StatementInvalid => e
      raise e unless /Mysql::Error: Duplicate entry/.match(e)      
      flash[:error] = 'There is a relation with Item ' + @cm_po_detail.cm_item_id.to_s + ' already created!'
  end

  def edit
    @cm_item_code = params[:cm_item_code]

    if params[:cm_po_detail]
      attrs = params[:cm_po_detail].dup
      @cm_po_detail.attributes = attrs
    end

    if request.post?
      @cm_item_code = params[:working_data][:cm_item_code]

      if @cm_po_detail.save
        # Only send notification if something was actually changed
        flash[:notice] = l(:notice_successful_update)

        Journal.create(:journalized_id => @cm_po_detail.cm_purchase_order_id,
          :journalized_type => "CmPurchaseOrder", :user_id => User.current.id,
          :notes => 'Edited relation with ' + @cm_item_code)

        redirect_to :controller => 'cm_purchase_orders',
          :action => 'show', :id => @cm_po_detail.cm_purchase_order_id
      else
        flash[:error] = 'Error saving relation with Document'
        end
     end
   rescue ActiveRecord::StaleObjectError
     # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    @cm_purchase_order_id = params[:po_id].to_i
    CmPoDetail.destroy(params[:relation_id])

    Journal.create(:journalized_id => @cm_purchase_order_id, :journalized_type => 'CmPurchaseOrder',
                  :user_id => User.current.id, :notes => 'Deleted relation with ' + params[:cm_item_code])

    redirect_to :controller => 'cm_purchase_orders', :action => 'show',
                :id => @cm_purchase_order_id
  end

  def find_cm_po_detail
    @cm_po_detail = CmPoDetail.find(params[:id])
    @project = @cm_po_detail.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
