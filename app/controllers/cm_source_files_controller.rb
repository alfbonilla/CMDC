class CmSourceFilesController < ApplicationController

  before_filter :find_project, :only => [:new, :index, :bulk_load]
  before_filter :find_cm_source_file, :only => [:edit, :destroy]

  accept_key_auth :index, :new, :edit, :destroy
      
  def index
    @cm_source_files = CmSourceFile.find(:all, :conditions => ['project_id=?', @project.id])
  end

  def new
    if request.get?
      @cm_source_file = CmSourceFile.new
    end
    
    if request.post?
      @cm_source_file = CmSourceFile.new(params[:cm_source_file])
      @cm_source_file.project = @project
    
      if @cm_source_file.save
        flash[:notice] = l(:notice_successful_create)
        redirect_back_or_default({ :action => 'index', :id => @project})
      else
        flash[:error] = 'Error creating new source file reference'
      end
    end
  end

  def edit
    if request.post?
      if @cm_source_file.update_attributes(params[:cm_source_file])
        flash[:notice] = l(:notice_successful_update)
        redirect_back_or_default({:action => 'index', :id => @project})
      else
        flash[:error] = "Edit not performed!!"
      end  
    end

  end

  def destroy
    @cm_source_file.destroy
    redirect_back_or_default({ :action => 'index', :id => @project})
  end

  def bulk_load
    #Present form in order to select the file to read
    if request.post?
      #Delete previous data
      if params[:cm_bulk_load_info][:remove_data] == '1'
        if CmSourceFile.delete_all(['project_id=?', @project.id])
          flash[:notice]='All records deleted from Source File model'
        else
          flash[:error]='Error deleting all the records from Source File model'
        end
      end

      #Open file
      @tempo_file = params[:cm_bulk_load_info][:file_name].local_path

      #Read
      file_name=""; revision=""; record_cnt=0; create_errors=false
      File.open(@tempo_file, "r").each do |line|
        file_name=""; revision=""; word_cnt=0
        record_cnt=record_cnt + 1
        line.split(" @ ").each do |num|
          case word_cnt
          when 0
            file_name=num
          when 1
            revision=num
          else
            flash[:error]='Strange info found at record ' + record_cnt.to_s + ' ignored...'
          end
          word_cnt=word_cnt+1
        end

        #Insert
        unless CmSourceFile.create(:file_name => file_name,
                                   :revision_at_load => revision,
                                   :project_id => @project.id)
          flash[:error] = 'Error creating new source file ' + record_cnt.to_s
          create_errors=true
        end
      end

      flash[:notice]='All records created succesfully' unless create_errors
      redirect_back_or_default({ :action => 'index', :id => @project})
    end
  end

  private

  def find_cm_source_file
    @cm_source_file = CmSourceFile.find(params[:id], :include => [:project])
    @project = @cm_source_file.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project
    @project = Project.find(params[:id])    
  rescue ActiveRecord::RecordNotFound
    render_404    
  end
    
end
