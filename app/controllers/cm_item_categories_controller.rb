class CmItemCategoriesController < ApplicationController

  before_filter :find_project, :only => [:new, :index]
  before_filter :find_cm_item_category, :only => [:edit, :destroy]
  before_filter :authorize, :except => :index
  
  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_item_categories = CmItemCategory.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    if request.get?
      @cm_item_category = CmItemCategory.new
    end
    
    if request.post?
      @cm_item_category = CmItemCategory.new(params[:cm_item_category])
      @cm_item_category.project = @project
      
      if @cm_item_category.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new item category'
      end
    end
  end

  def edit
    if request.post?
      if @cm_item_category.update_attributes(params[:cm_item_category])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    begin
    @cm_item_category.destroy
    rescue RuntimeError => e
      flash[:error]='Item Category not deleted: ' + e.message
    ensure
    redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_item_category
    @cm_item_category = CmItemCategory.find(params[:id], :include => [:project])
    @project = @cm_item_category.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
end
