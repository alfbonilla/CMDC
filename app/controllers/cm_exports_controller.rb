class CmExportsController < ApplicationController
  #require 'tempfile'

  before_filter :find_project, :only => [:export_data]

  include CmCommonHelper
  helper :cm_exports
  include CmExportsHelper
  helper :cm_rids
  include CmRidsHelper
  helper :cm_changes
  include CmChangesHelper
  helper :cm_risks
  include CmRisksHelper
  helper :cm_reqs
  include CmReqsHelper

  def export_data

       # Columns distribution based on code, name, login... attributes
 @cols_just_name=["status_id", "release_id", "type_id", "project_id", "classification_id",
                    "phase_id", "rlse_detected_id", "rlse_solved_id", "rlse_verified_id",
                    "cm_item_group_id", "category_id", "close_out_id", "open_release_id",
                    "originator_company_id", "implementation_release_id", "rlse_removed_id",
                    "verification_method_id", "rlse_expected_id"]

 @cols_with_login=["approved_by", "author_id", "assigned_to_id"]
 @cols_name_and_code=["from_company", "to_company", "supplier_id", "vendor_id", "cm_doc_id",
                    "affected_doc_id", "affected_item_id", "company_id",
                    "cm_nc_id", "cm_change_id", "subsystem_id", "cm_req_id"]

 @cols_with_helper=["internal_status_id", "external_status_id", "classification", "compliance",
                    "implementation", "impact", "priority_ranking", "risk_exposure", "status"]

    @object_to_export = params[:object_to_export]
   
    if request.get?      
      get_object_columns
      @separator="TAB"
      @outfile_name = "export_data_from_CMDC.txt"
      @format=params[:format]

    end
    
    if request.post?
      @outfile_name=params[:outfile]
      @col_list = params[:ids]
      @filter_code = params[:filter_code]
      @format=params[:format]
      @separator = params[:separator]
      @data_quotes=params[:data_quotes]
      @export_error=false

      unless params[:ids]
        flash[:error] = 'No columns selected!'
        get_object_columns
      else
        @output_file="";
        @controller=""
        if params[:separator] == 'TAB'
          @separator = "\t"
        else
          @separator = params[:separator]
        end

#        file_name = File.dirname(__FILE__) + "/EXPORT_DATA_FROM_CMDC.dat"
#        @my_file = File.new(file_name, 'w')

        @record_cnt=0
        begin
          get_selected_data
        rescue Exception => e
          flash[:error] = e.message + " (record number:"+@record_cnt.to_s+")"
          get_object_columns
          @export_error=true
        end

#        @my_file.flush
#        logger.error "----- File Path:" + file_name

#        flash[:notice] = 'Export executed successfully!'

#        file_name2 = file_name.gsub("\\" , "\/")
#        logger.error "----- File Path(2):" + file_name2
      if @export_error
          redirect_to :controller => @controller,
            :action => 'index', :id => @project
      else
          respond_to do |format|
            format.html {
              redirect_back_or_default({ :controller => @controller, :action => 'index',
              :id => @project}) }
            format.csv  {
              send_data(@output_file,
                  :type => 'text/csv; header=present', :filename => @outfile_name) }
  #             send_file(file_name,
  #                :type => 'text/csv; header=present', :filename => 'export_from_CMDC.csv') }
          end
      end
#        @my_file.close
        #File.delete(file_name)
      end
    end
  end





 private


 def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
 end




 def get_object_columns
  
 #logger.error("Numero columnas @cm_export_columns" + @cm_export_columns.length.to_s) unless @cm_export_columns.nil?
  case @object_to_export
  when "CmDelivery"
    @cm_export_columns = CmDelivery.column_names
  when "CmItem"
    @cm_export_columns = CmItem.column_names
  when "CmPurchaseOrder"
    @cm_export_columns = CmPurchaseOrder.column_names
  when "CmChange"
    values_to_get = ["version","applicable","author_id","comments"]
    @cm_export_columns = CmChange.column_names
    CmChangesVersion.column_names.each do |col| 
      if values_to_get.include?(col)
         @cm_export_columns << "version:" + col
      end
    end
  when "CmDoc"
   # @cm_export_columns = Array.new
     values_to_get = ["version","applicable","author_id","comments","physical_location","status_id","assigned_to_id"]
   #  @cm_export_columns.clear unless @cm_export_columns.empty?
    # if @cm_export_columns.length > 0
    #
    #      @cm_export_columns.clear
     #     logger.error("DENTRO IF El tamano de @cm_export_columns : " + @cm_export_columns.length.to_s)
    # else
    #       logger.error("DENTRO ELSE El tamano de @cm_export_columns : " + @cm_export_columns.length.to_s)
    # end
    @cm_export_columns = CmDoc.column_names
   #  logger.error("DESPUES DE @cm_export_columns = CmDoc.column_names LENGHT=: " + @cm_export_columns.length.to_s)
  #  i=0
    CmDocsVersion.column_names.each do |col| 
    if values_to_get.include?(col)
        @cm_export_columns <<= "version:" + col
   #     i = i +1
      end
    end
    #logger.error("El valor elemento metidos son: " + i.to_s)
    #logger.error("DESPUES de VERSIONS el tamano de @cm_export_columns : " + @cm_export_columns.length.to_s)

  when "CmBoard"
    @cm_export_columns = CmBoard.column_names
  when "CmNc"
    @cm_export_columns = CmNc.column_names
  when "CmRid"
    @cm_export_columns = CmRid.column_names
  when "CmSmr"
    @cm_export_columns = CmSmr.column_names
  when "CmWa"
    @cm_export_columns = CmWa.column_names
  when "CmRisk"
    @cm_export_columns = CmRisk.column_names
  when "CmReq"
    @cm_export_columns = CmReq.column_names
  end
 end

 #This function convert a colummn value to a representative one.
 #Example: if the value of column name "assigned_to_id" is 2, this number will be tranformer in this case
 #to the name of the person who has been assigned for example "Felipe".
 def trans_get_selected_data(data_row,sel_col,first_row)
        @current_code = ""
        row_to_w = ""
        
        table_col = data_row.column_for_attribute(sel_col)
        if table_col.name == sel_col

          # Value does not need tranformation
          column_data=eval "data_row.#{sel_col}"

          if table_col.name == "code" or table_col.name == "smr_code" or
              table_col.name == "cm_board_code" or table_col.name == "cm_wa_code"
            @current_code = column_data
          end

          # Get again the column_data value for those cases where some model name exist:
          # at this point, column_data will have "3" for status_id, after this unless sentence,
          # column_data will have the status 3 NAME or CODE...
          unless column_data.blank? or column_data.to_s == "0"
            # Attributes JUST with name
            if @cols_just_name.include?(sel_col)
              sel_col_name=get_model_name(sel_col, params[:object_to_export])

              begin
                column_data=eval "data_row.#{sel_col_name}.name"
              rescue Exception => exc
                raise "Data Error: does not exist name attribute for "+sel_col_name+"["+@current_code+"]"
              end

            else
              # Attributes with name and login options
              if @cols_with_login.include?(sel_col)
                sel_col_name=get_model_name(sel_col, params[:object_to_export])

                case params[:userinfo]
                when "Name"
                  begin
                    column_data=eval "data_row.#{sel_col_name}.name"
                  rescue Exception => exc
                    raise "Data Error: does not exist name attribute for "+sel_col_name+"["+@current_code+"]"
                  end
                when "Login"
                  begin
                    column_data=eval "data_row.#{sel_col_name}.login"
                  rescue Exception => exc
                    raise "Data Error: does not exist login attribute for "+sel_col_name+"["+@current_code+"]"
                  end
                end
              else
                # Attributes with name and code options
                if @cols_name_and_code.include?(sel_col)
                  sel_col_name=get_model_name(sel_col, params[:object_to_export])
                  case params[:codeinfo]
                  when "Name"
                    begin
                      column_data=eval "data_row.#{sel_col_name}.name"
                    rescue Exception => exc
                      raise "Data Error: does not exist name attribute for "+sel_col_name+"["+@current_code+"]"
                    end
                  when "Code"
                    begin
                      column_data=eval "data_row.#{sel_col_name}.code"
                    rescue Exception => exc
                      raise "Data Error: does not exist code attribute for "+sel_col_name+"["+@current_code+"]"
                    end
                  end
                else
                  if @cols_with_helper.include?(sel_col)
                    case sel_col
                    when "classification"
                      column_data=change_classification_to_s(column_data)
                    when "compliance"
                      column_data=change_compliance_to_s(column_data)
                    when "implementation"
                      column_data=change_implementation_to_s(column_data)
                    when "internal_status_id"
                      column_data=change_internal_status_to_s(column_data)
                    when "external_status_id"
                      column_data=change_external_status_to_s(column_data)
                    when "impact", "risk_exposure", "priority_ranking"
                      column_data=change_impact_to_s(column_data)
                    end
                  end
                end
              end
            end
          end

          if column_data.blank?
            if @data_quotes
              column_string='"  "'
            else
              column_string=" - "
            end
          else
            case table_col.type.to_s
            when "datetime"
              if @data_quotes
                column_string='"'+column_data.strftime("%Y-%m-%d")+'"'
              else
                column_string=column_data.strftime("%Y-%m-%d")
              end
            else
              column_string=column_data.to_s.gsub("\r\n", " || ") unless column_data.nil?
              if @data_quotes
               column_string='"'+column_string.gsub("\n", " || ")+'"' unless column_string.nil?
              else
               column_string=column_string.gsub("\n", " || ") unless column_string.nil?
              end
            end
          end

          if first_row
            row_to_w = row_to_w + column_string
            first_row = false
          else
            row_to_w = row_to_w + @separator + column_string
          end
        end

   return row_to_w, first_row
 end

  def get_selected_data
    first_row=true
    f_code="%" + @filter_code + "%"
    select_from_tables (f_code)

    #Header
    headers=""
    @col_list.each do |sel_col|
      headers << sel_col + @separator
    end
    @output_file = headers + "\r"


    # Rows selected
    @current_code = ""
    version_cols_list = []
    @result_d.each do |data_row|
      row_to_w = ""
      version_cols_list = []
      first_row=true
      @Doc_or_change_data=""
   #   @output_file=""
      @record_cnt=@record_cnt+1;

      @col_list.each do |sel_col|

       if sel_col.include? "version:"
          #logger.error("<<<<<sel_col include 'version:' " +sel_col.to_s)# Columns with data from docs or changes versions are later treated
          sel_col = sel_col.slice(sel_col.index(':')+1,sel_col.length)

          version_cols_list << sel_col
       else
        row_to_w,first_row =  trans_get_selected_data(data_row,sel_col,first_row)
        @Doc_or_change_data = @Doc_or_change_data + row_to_w
       end
      end
      #In this point the current data row is in row_to_w,
      #now it's necessary to check if the doc has any version.

      if version_cols_list.any?
        # Recover data for version fields
        if params[:object_to_export] == "CmDoc"
          versions = data_row.cm_docs_versions
        else
          versions = data_row.cm_changes_versions
        end
        versions.each do |version_record| #Loop for the versions of the current doc/change
        # TRY  TO REFACTOR THIS CODE!!!!!
        version_to_w=""
          version_cols_list.each do |sel_col| # Take just the colummns with 'version:'
           
              row_to_w,first_row =  trans_get_selected_data(version_record,sel_col,first_row)
              version_to_w = version_to_w + row_to_w #recover
         end
          #there is one entry for each doc version, example:
          #DOC1 Version 1.A
          #DOC1 Version 1.B
          #DOC2 Version 1.0
         @output_file = @output_file + @Doc_or_change_data + version_to_w + "\r"

        end #End of each for all the versions in the doc or change
   
     else

        @output_file = @output_file + @Doc_or_change_data + "\r"
     end

    #FIN

    end
end

  def select_from_tables (f_code)
   case params[:object_to_export]
    when "CmDelivery"
      @cm_table_columns = CmDelivery.columns
      @controller = "cm_deliveries"
      conditions = prepare_conditions(CmDelivery, @project, params[:query_subp],f_code)
      @result_d = CmDelivery.find(:all, :include => [:project, :author,
        :source_company, :target_company, :approver, :release, :status],
        :conditions => conditions)

    when "CmItem"
      @controller = "cm_items"
      conditions = prepare_conditions(CmItem, @project, params[:query_subp],f_code)
      @result_d = CmItem.find(:all, :include => [:project, :status, :author,
        :group, :category, :classification, :type],
        :conditions => conditions)

    when "CmPurchaseOrder"
      @controller = "cm_purchase_orders"
      conditions = prepare_conditions(CmPurchaseOrder, @project, params[:query_subp],f_code)
      @result_d = CmPurchaseOrder.find(:all, :include => [:project, :supplier, :vendor, :author],
        :conditions => conditions)

    when "CmChange"
      @controller = "cm_changes"
      conditions = prepare_conditions(CmChange, @project, params[:query_subp],f_code)
      @result_d = CmChange.find(:all, :include => [:project, :status, :author, :type, :change_doc],
        :conditions => conditions)

    when "CmDoc"
      @controller = "cm_docs"
      conditions = prepare_conditions(CmDoc, @project, params[:query_subp],f_code)
      @result_d = CmDoc.find(:all, :include => [:project, :author, :type, :company, :category],
        :conditions => conditions)


    when "CmBoard"
      @controller = "cm_boards"
      conditions = prepare_conditions(CmBoard, @project, params[:query_subp],f_code)
      @result_d = CmBoard.find(:all, :include => [:project, :company, :author, :type],
        :conditions => conditions)

    when "CmNc"      
      @controller = "cm_ncs"   
      conditions = prepare_conditions(CmNc, @project, params[:query_subp],f_code)
      @result_d = CmNc.find(:all, :include => [:project, :type, :author, :company, :status, :classification,
          :phase], :conditions => conditions)

    when "CmRid"
      @controller = "cm_rids"
      conditions = prepare_conditions(CmRid, @project, params[:query_subp],f_code)
      @result_d = CmRid.find(:all, :include => [:project, :close_out, :author, :originator_company],
        :conditions => conditions)


    when "CmSmr"
      @controller = "cm_smrs"
      conditions = prepare_conditions(CmSmr, @project, params[:query_subp],f_code)
      @result_d = CmSmr.find(:all, :include => [:project, :nonConformance, :author],
        :conditions => conditions)

    when "CmWa"
      @controller = "cm_was"
      conditions = prepare_conditions(CmWa, @project, params[:query_subp],f_code)
      @result_d = CmWa.find(:all, :include => [:author, :rlse_removed, :nonConformance],
        :conditions => conditions)

    when "CmRisk"
      @controller = "cm_risks"
      conditions = prepare_conditions(CmRisk, @project, params[:query_subp],f_code)
      @result_d = CmRisk.find(:all, :include => [:author, :project, :assignee, :status],
        :conditions =>conditions)

    when "CmReq"
      @controller = "cm_reqs"
      conditions = prepare_conditions(CmReq, @project, params[:query_subp],f_code)
      @result_d = CmReq.find(:all, :include => [:project, :type, :author, :subsystem, :classification],
        :conditions => conditions)
    end


  end


  #prepare_conditions, built the mysql query needed to perfom the export.
  #Paramas
  #object: The object to prepare the conditions.
  #project: "father" project to the object.
  #include_subproject: if this variable is not null, the "son" project will have include in the conditions.
  def prepare_conditions (object,project,include_subproject,f_code)
    #Get subprojects
    columns, values = prepare_get_for_projects(object,project,include_subproject,"not_nill")
    #The selection could be filter by *code
    columns << "and code LIKE ?"
    values << f_code
     
    conditions = [columns]
    values.each do |value|
      conditions << value
    end      
    #return conditions
    return conditions
  end

end



