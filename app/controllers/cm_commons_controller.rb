class CmCommonsController < ApplicationController

  before_filter :find_project, :only => [:index, :import_objects, :search_cmdc, 
    :golden_rules]
  before_filter :authorize, :except => [:search_cmdc, :golden_rules]

  include CmImportAssistant
  include CmRidsHelper
  include CmReqsHelper

  def index
    #MAIN REDMINE_CM PLUGIN MENU
  end

  def import_objects
    #Present form in order to select the file to read
    if params[:working_data].nil?
      @cmdc_object=params[:cmdc_object]
      @namecode="name"
    else
      @cmdc_object=params[:working_data][:cmdc_object]
    end

    case @cmdc_object
    when "rids"
      @cm_export_columns = CmRid.column_names
      @obj="CmRid"
      @caller_cont="cm_rids"
    when "tes"
      @cm_export_columns = CmReq.column_names
      @obj="CmReq"
      @caller_cont="cm_reqs"
    end

    # Remove those columns that are automatically completed
    @cm_export_columns.delete("project_id")
    @cm_export_columns.delete("created_on")
    @cm_export_columns.delete("updated_on")
    
    if request.post?
      # Log vble to show after the import process
      @log_results = "<p><strong>CMDC Import Log</strong></p><p>Date:" +
        Time.now.strftime("%Y-%m-%d") +"</p><p><ul>"
      
      result_ok=import_sentences()

      @log_results = @log_results + "</ul></p>"

      if result_ok
        respond_to do |format|
          format.html { render(:template => 'cm_commons/import_objects_log.rhtml', :layout => !request.xhr?) }
        end
      end
    end
  end

  def search_cmdc
    # Prepare list with objects
    @cmdc_objects = {'Items' => 0, 'Maintenance Logs' => 1, 'Traceability Elements' => 2, 'Request for Changes' => 3,
      'Documents' => 4, 'Meetings' => 5, 'Non-Conformances' => 6, 'Work Around' => 7,
      'RIDs' => 8, 'Risks' => 9, 'SMRs' => 10, 'Tests' => 11, 'Test Records' => 12, 'Test Campaigns' => 13,
      'Deliveries' => 14}

    if request.post?

      if params[:text_to_search].blank?
        flash[:error]='Text to search is empty'
      else
        txt="%" + params[:text_to_search] + "%"

        case params[:selected_object]
        when "0"
          @caller_cont="cm_items"
          @list=CmItem.find(:all, :conditions => ["(comments LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "1"
          @caller_cont="cm_mnt_logs"
          @list=CmMntLog.find(:all, :conditions => ["(configuration_comments LIKE ? or installation_log LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "2"
          @caller_cont="cm_reqs"
          @list=CmReq.find(:all, :conditions => ["(comments LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "3"
          @caller_cont="cm_changes"
          @list=CmChange.find(:all, :conditions => ["(reason LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "4"
          @caller_cont="cm_docs"
          @list=CmDoc.find(:all, :conditions => ["(physical_location LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "5"
          @caller_cont="cm_boards"
          @list=CmBoard.find(:all, :conditions => ["(board_body LIKE ? or conclusions LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "6"
          @caller_cont="cm_ncs"
          @list=CmNc.find(:all, :conditions => ["(analysis LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "7"
          @caller_cont="cm_was"
          @list=CmWa.find(:all, :conditions => ["(comments LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "8"
          @caller_cont="cm_rids"
          @list=CmRid.find(:all, :conditions => ["(discrepancy LIKE ? or disposition LIKE ? or author_response LIKE ?) and project_id=?",
            txt, txt, txt, @project.id])
        when "9"
          @caller_cont="cm_risks"
          @list=CmRisk.find(:all, :conditions => ["(comments LIKE ? or description LIKE ?) and project_id=?",
            txt, txt, @project.id])
        when "10"
          @caller_cont="cm_smrs"
          @list=CmSmr.find(:all, :conditions => ["description LIKE ? and project_id=?",
            txt, @project.id])
        when "11"
          @caller_cont="cm_tests"
          @list=CmTest.find(:all, :conditions => ["(objective LIKE ? or steps_and_checkpoints LIKE ? \
                or pass_fail_criteria LIKE ?) and project_id=?",
            txt, txt, txt, @project.id])
        when "12"
          @caller_cont="cm_test_records"
          @list=CmTestRecord.find(:all, :conditions => ["(execution_log LIKE ? or execution_evidences LIKE ?) \
                and project_id=?",
            txt, txt, @project.id])
        when "13"
          @caller_cont="cm_test_campaigns"
          @list=CmTestCampaign.find(:all, :conditions => ["description LIKE ? and project_id=?",
            txt, @project.id])
        when "14"
          @caller_cont="cm_deliveries"
          @list=CmDelivery.find(:all, :conditions => ["description LIKE ? and project_id=?",
            txt, @project.id])
        end
        flash[:notice]='Search finished successfully'
      end
    end
  end

  def cmdc_mypage
    @cmdc_objs = []
  end

  private
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def import_sentences
    if params[:cm_import_objects][:file_name].nil? or 
       params[:cm_import_objects][:separator].nil? or
       params[:cm_import_objects][:input_mask].nil?
      flash[:error]='File Name, Separator and Mask are mandatory fields!'
      @namecode="name"
    else

      if params[:cm_import_objects][:review_version] == '1'
        flash[:notice]='Version field will be reviewed!'
      end

      @file_name = params[:cm_import_objects][:file_name].local_path
      @input_mask = params[:cm_import_objects][:input_mask]

      # Assistant treat mask and prepare hash structure for later performing
      # here the insert or update operation
      begin
        import(@obj, @file_name,
            params[:cm_import_objects][:separator],
            params[:cm_import_objects][:input_mask],
            @project.id)
      rescue RuntimeError => e
        flash[:error] = e.message
        return
      end

      # Perform DB modifications
      @model_object=@obj.constantize
      @model_object.transaction do
        @output.each do |sentence|         

          begin
            if sentence["ACTION"]=="Insert"
              sentence.delete("ACTION")
              @obj_to_update=@model_object.new(sentence)
              if @obj_to_update.save
                @log_results = @log_results + "<li><strong>Insert Ok:</strong>" + sentence.to_s + "</li>"
              else
                @log_results = @log_results + "<li><strong>Insert Error:</strong>" +
                    @obj_to_update.errors.full_messages.to_sentence + "</li>"
              end
            else
              sentence.delete("ACTION")
              @obj_to_update=@model_object.find(:first,
                :conditions => ["code=? and project_id=?", sentence["code"], @project.id])
              @obj_to_update.init_journal(User.current)
              @obj_to_update.attributes=sentence
              if @obj_to_update.save
                # If the object has no journal details, there is no modification!
                if @obj_to_update.current_journal.details.empty?
                  @log_results = @log_results + "<li><strong>No Modifications:</strong>" +
                    sentence.to_s + "</li>"
                else
                  @log_results = @log_results + "<li><strong>Update Ok:</strong>" +
                    sentence.to_s + "</li>"
                end
              else
                @log_results = @log_results + "<li><strong>Insert Error:</strong>" +
                    @obj_to_update.errors.full_messages.to_sentence + "</li>"
              end
            end
          rescue ActiveRecord::StatementInvalid => e
            # If there is an error, not in validation but in DB, stop exec
            flash[:error] = "Error importing data:" + e.message
            return
          end
        end
      end

      flash[:notice]='All records treated successfully!!'
    end
  end
  
end
