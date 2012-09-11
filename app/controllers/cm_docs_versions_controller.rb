class CmDocsVersionsController < ApplicationController
  before_filter :find_cm_docs_version, :only => :edit
  before_filter :find_project, :only => :new

  accept_rss_auth :new, :edit, :destroy
      
  def index
    @cm_docs_versions = CmDocsVersion.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def new
    @version_editable = true
       
    if request.get?
      prepare_combos()

      @cm_docs_version = CmDocsVersion.new
      @cm_docs_version.cm_doc_id = params[:doc_id]

      status=CmDocStatus.default(@project.id)
      unless status
        render_error "No Default value defined for document statuses!!"
        return
      end
      @cm_docs_version.status = status

      @doc_to_relate = CmDoc.find(@cm_docs_version.cm_doc_id)
    end   

    if request.post?
      @cm_docs_version = CmDocsVersion.new(params[:cm_docs_version])
      @cm_docs_version.author = User.current
      @cm_docs_version.updated_on = Time.now
      
      if @cm_docs_version.save
        flash[:notice] = l(:notice_successful_update) +
          " *IMPORTANT*: Before start to modify new doc version: ACTIVATE CHANGES " +
          "TRACKING IN DOC and ACCEPT ALL PREVIOUS CHANGES!!"

        #Deliver mail
        Mailer.deliver_cmdc_info(User.current, @project, @cm_docs_version, 'cm_docs_versions')

        redirect_back_or_default({ :controller => 'cm_docs', :action => 'show',
            :id => @cm_docs_version.cm_doc_id})
      else
        @doc_to_relate = CmDoc.find(@cm_docs_version.cm_doc_id)
        prepare_combos()
        @cm_docs_version.errors.add_to_base("Error creating new version to document!")
        flash[:error] = @cm_docs_version.errors.full_messages.to_sentence
      end
    end
  end

  def edit
    @notes = params[:notes]
    @cm_docs_version.init_journal(User.current, @notes)

    if request.get?
      prepare_combos()

      if CmDeliveriesObject.find(:first, :conditions => ["x_id=? and x_type=? and rel_string=?",
          @cm_docs_version.cm_doc_id, "CmDoc", @cm_docs_version.version])
        @version_editable = false
      else
        @version_editable = true
      end
    end
    
    if request.post?    
      @cm_docs_version.author = User.current
      @cm_docs_version.updated_on = Time.now

      if @cm_docs_version.update_attributes(params[:cm_docs_version])
        flash[:notice] = l(:notice_successful_update)

#        Journal.create(:journalized_id => params[:cm_docs_version][:cm_doc_id].to_i,
#          :journalized_type => "CmDoc", :user_id => User.current.id,
#          :notes => 'Edited version ' + @cm_docs_version.version)

        # Deliver email
        Mailer.deliver_cmdc_info(User.current, @project, @cm_docs_version, 'cm_docs_versions')

        redirect_back_or_default({ :controller => 'cm_docs', :action => 'show',
            :id => @cm_docs_version.cm_doc_id})
      else
        prepare_combos()
        @doc_to_relate = CmDoc.find(@cm_docs_version.cm_doc_id)

        @cm_docs_version.errors.add_to_base("Error updating version to document!")
        flash[:error] = @cm_docs_version.errors.full_messages.to_sentence
      end  
    end

  end

  def destroy
    begin
      @cm_docs_version = CmDocsVersion.find(params[:id])
      @cm_docs_version.destroy

      Journal.create(:journalized_id => params[:cm_doc_id].to_i, :journalized_type => 'CmDoc',
        :user_id => User.current.id, :notes => 'Deleted version ' + @cm_docs_version.version)
      
    rescue RuntimeError => e
      flash[:error]='Document Version not deleted: ' + e.message

    ensure
    redirect_back_or_default({ :controller => 'cm_docs', :action => 'show',
            :id => @cm_docs_version.cm_doc_id})
    end
  end

  private

  def prepare_combos
    @cm_doc_assignees = @project.assignable_users
    unless @cm_doc_assignees
      render_error "There are no users assigned to the Project!"
      return
    end
    @cm_doc_statuses = CmDocStatus.find(:all, 
      :conditions => ['project_id in (?,?)', 0, @project.id])
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_cm_docs_version
    @cm_docs_version = CmDocsVersion.find(params[:id],:include => [:cm_doc, :status, :assignee])
    @project = @cm_docs_version.cm_doc.project
    @doc_to_relate = CmDoc.find(@cm_docs_version.cm_doc_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
