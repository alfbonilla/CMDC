module CmImportAssistant

  include CmCommonHelper

  def treat_mask(input_mask, object_type)
    #return array with list of columns and type of them (if any)
    cols = []
    col = []
    sep_char=";"

    #Masks
    #1st char=>CMDC indicator (C for code, N for name and S for self)
    input_mask.split(sep_char).each_with_index do |xcol, indx|

      #database_type=xcol[0,1]
      cmdc_field=xcol[0,1]
      column_name=xcol[1, xcol.length - 1]

      case @model_object.columns_hash[column_name].type.to_s
      when "string"
        database_type="V"
      when "text"
        database_type="T"
      when "integer"
        database_type="I"
      when "datetime", ":date"
        database_type="D"
      when "boolean"
        database_type="B"
      when "decimal"
        database_type="F"
      else
        raise "Import error. Database Type not controlled " +
          @model_object.columns_hash[column_name].type.to_s + "!!"
      end
      col = [column_name, database_type, cmdc_field]

      #Return position of "code" field in the input record
      case object_type
      when "CmBoard"
        @field_code="cm_board_code"
      else
        @field_code="code"
      end

      @code_position=indx if column_name==@field_code

      cols << col
      @output_cols << col[0] + ", "
    end

    if cols.size > 0
      if cols[cols.size - 1][1] == "T"
        raise "Import error. Import file includes a TEXT field as the last column!!"
      end
    end

    if input_mask.include? "author_id"
      @output_cols << "project_id, created_on, updated_on "
    else
      @output_cols << "author_id, project_id, created_on, updated_on "
    end
    cols
  end

  def import(object_type, filename, sep_char, input_mask, project_id, ret_values=false)
    # 2 uses:
    # 1-Import trace => called with option @ret_values=true. It returns @output_cols:
    #                   list of columns separated by commas (string) and
    #                   @output_with_values: array of records in files composed by array of values
    # 2-Import       => the update of the db is performed directly in this modules
    #
    # Right now, 2 objects can be imported: CmRids and CmReqs. Objects require
    # having CODE field (for update [plus the project, of course] and for insert)
    record_cnt = 0
    @ret_values=ret_values
    @project_id =  project_id
    @treating_text = false
    @last_col = false
    @include_author=true
    if sep_char == "TAB"
      @sep_char = "\t"
    else
      @sep_char = sep_char
    end
    
    @include_author=false if input_mask.include? "author_id"
   
    @col_cnt = 0
    @code_position = -1    # this vble has the position of the code field in the input file
    @field_code = ""
    @code_value_in_file = ""

    @output = []
    @output_cols = ""
    @output_with_values = []
    @output_values =Array.new

    @insert_record=true    # False value means to update

    @model_object=object_type.constantize

    begin
      @columns=treat_mask(input_mask, object_type)
    rescue RuntimeError => e
      raise "Import Validation Error. Mask included is wrong!\n" + e.message
    end

    # Controlling the position of the code field to use for updates and to include
    # as mandatory in inserts
    raise "Import Validation Error. Code field not included in input file!" if @code_position == -1

#    logger.error("Columns extracted:")
#    logger.error("Number of cols:" + @columns.size.to_s)
#    @columns.each do |col|
#      logger.error("Name:" + col[0] + ", DB Type:" + col[1] + ", CMDC Type:" + col[2])
#    end

    @columns_hash=create_hash()

    #Read input File
    File.open(filename, "r").each do |@iline|

      next if @iline.length == 0 and not @treating_text

      record_cnt=record_cnt + 1

#      logger.error("Parsing record (" + record_cnt.to_s + ")<" + @iline + ">")

      # For each column detected in the mask, extract its value from the file
      extract_values_from_file(object_type, record_cnt)

      #If all the cols have been treated, initialize for next record
      if @col_cnt == @columns.size
        prepare_sentences()

        # Initialize vbles for next record (logic) to read
        # Logic: after treat all the EOL "coming" in real records
        @col_cnt = 0
        @column_data = ""
        @output_values =Array.new
        @insert_record=true
      end
    end

    if @ret_values
      # When just values are required
      return @output_cols, @output_with_values
    else
      return @output
    end
  end

  private

  def extract_values_from_file(object_type, record_cnt)
    # Extract values from file based on the columns array
    # 1. Complete @output_values array with a element per value
    # 2. Complete @columns_hash hash with column and value
    #    "column1" => value1, "column2" => "value2",...
    while @col_cnt < @columns.size
      unless @treating_text
        @column_data = parse_next_field(@col_cnt)
      else
        rest = parse_next_field(@col_cnt)
        @column_data = @column_data + "\n" + rest #  Removed: "\n" +
      end

      if @treating_text
        #read a new record
        break
      else
        #treat another column
        if @col_cnt == @code_position
          @insert_record=search_code(@column_data)
          @code_value_in_file=@column_data
        end

        case @columns[@col_cnt][2]     #cmdc_type
        when "S"
          # If data is enclosed in quotes, remove them
          # Excel use to put quotes when the cell has EOLs
          if @column_data[0, 1] == "\"" and
             @column_data[@column_data.length - 1, 1] == "\""
           
            if @ret_values
              @output_values << @column_data[1, @column_data.length - 2]
            else
              @columns_hash[@columns[@col_cnt][0]]=@column_data[1, @column_data.length - 2]
            end
          else
            if @ret_values
              @output_values << @column_data
            else
              @columns_hash[@columns[@col_cnt][0]]=@column_data
            end
          end

        when "C", "N"
          #search for id
          referenced_id = get_id_from_model(object_type, @columns[@col_cnt][2],
                                            @columns[@col_cnt][0], @column_data,
                                            record_cnt)
          @output_values << referenced_id.to_s if @ret_values
          @columns_hash[@columns[@col_cnt][0]]=referenced_id
        else
          raise "Input File Validation Error: CMDC indicator not C, N or S" +
            ". Record(" + record_cnt.to_s  + ") Column: " + @columns[@col_cnt][0]
        end

        @col_cnt += 1
      end
    end
  end

  def prepare_sentences
    # Add to the arrays to be returned the sentence with the SQL statement
    # 1. Complete @output array with the INSERT, UPDATE SQL statements and the
    #    @columns_hash generated, adding columns like project_id, updated_on...
    # 2. Complete @output_with_values array with the values in @output_values
    #    after adding the project_id, updated_on...
    # NOTICE than columns like updated and created_on are automatically managed
    # by ROR, so they don't need to be completed
    if @ret_values
      @output_values << User.current.id.to_s if @include_author
      @output_values << @project_id.to_s
      @output_values << Time.now.strftime("%Y-%m-%d %H:%M")
      @output_values << Time.now.strftime("%Y-%m-%d %H:%M")
      @output_with_values << @output_values
    end

    if @insert_record
      @columns_hash["author_id"]=User.current.id if @include_author
      @columns_hash["project_id"]=@project_id
      @columns_hash["ACTION"]="Insert"
    else
      @columns_hash["ACTION"]="Update"
    end

#    logger.error("Saving the hash with code:" + @columns_hash["code"] + " => " + @columns_hash["ACTION"])

    obj=@columns_hash.dup
    @output << obj
  end

  def search_code(value_in_file)
    code_in_db=@model_object.find(:first, :conditions => ["project_id = ? and #{@field_code} = ?",
      @project_id, value_in_file] )
    if code_in_db.nil?
      # Record not in DB : INSERT
      return true
    else
      # Record in DB : UPDATE
      return false
    end
  end

  def parse_next_field(cnt)

    #IMPORTANT: This code is multiplatform dependent?? For linux and mac,
    #           the values for eol and eof are half than in windows. Depends on chomp!!

#    logger.error("-parse next field. col:" + col_to_get[0] + ", counter:" + cnt.to_s)
#    logger.error("-line to review:<" + @iline + ">")

    x=@iline.index(@sep_char)
    #If there is no separator
    if x.nil?
      #If this is not the last column
      cnt += 1
      if cnt == @columns.size
        #Do not include the end of record and the end of line!
        nfield = @iline[0..@iline.length].chomp
#        logger.error("Treating last field:" + col_to_get[0])
        @treating_text = false
        @last_col = true
      else
        @treating_text = true
        @last_col = false
#        logger.error("Treating text field:" + col_to_get[0])
        nfield = @iline[0..@iline.length].chomp
      end
    else
      #When the SEP is in the first column
      if x== 0
        nfield = ""
      else
        nfield = @iline[0..x-1]
      end
      @iline = @iline[x+@sep_char.length..@iline.length]
#      logger.error("Treating regular field:" + col_to_get[0])
      @treating_text = false
      @last_col = false
    end

    return nfield
  end

  def get_id_from_model(object_type, code_or_name, column_name, column_data, record_cnt)

#     .error("Ob.Type:" + object_type + ", Code/Name:" + code_or_name)
#    logger.error("Column Name:" + column_name + ", Column Data:" + column_data)
    review_object=true
    id_to_return=0

    #Just those common columns are treated before than the own object columns
    case column_name
    when "author_id", "assigned_to_id"
      usr=User.find(:first, :conditions => ['login = ?',
          column_data])
      if usr.nil?
        raise "Input File Validation Error: User Login " + column_data + " not found." +
          " Record(" + record_cnt.to_s  + ") "
      else
        id_to_return=usr.id
      end
      review_object=false
    when "subsystem_id"
      if code_or_name == "C"
        sub=CmSubsystem.find(:first, :conditions => ['project_id = ? and code = ?',
          @project_id, column_data])
      else
        sub=CmSubsystem.find(:first, :conditions => ['project_id = ? and name = ?',
          @project_id, column_data])
      end
      if sub.nil?
        raise "Input File Validation Error: Subsystem " + column_data + " not found." +
          " Record(" + record_cnt.to_s  + ") "
      else
        id_to_return=sub.id
      end
      review_object=false
    when "open_release_id"
      #name or code => always name
      ver=Version.find(:first, :conditions => ['project_id = ? and name = ?',
          @project_id, column_data])
      if ver.nil?
        raise "Input File Validation Error: Version " + column_data + " not found." +
          " Record(" + record_cnt.to_s  + ") "
      else
        id_to_return=ver.id
      end
      review_object=false
    end

    if review_object
      case object_type
      when "CmRid"
        case column_name
        when "affected_doc_id"
          if code_or_name == "C"
            doc=CmDoc.find(:first, :conditions => ['project_id = ? and code = ?',
              @project_id, column_data])
          else
            doc=CmDoc.find(:first, :conditions => ['project_id = ? and name = ?',
              @project_id, column_data])
          end
          if doc.nil?
            raise "Input File Validation Error: Document " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            doc.id
          end
        when "affected_item_id"
          if code_or_name == "C"
            doc=CmItem.find(:first, :conditions => ['project_id = ? and code = ?',
              @project_id, column_data])
          else
            doc=CmItem.find(:first, :conditions => ['project_id = ? and name = ?',
              @project_id, column_data])
          end
          if doc.nil?
            raise "Input File Validation Error: Item " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            doc.id
          end
        when "category"
          x=change_category_to_i(column_data)
          if x.nil?
            raise "Input File Validation Error: Category value not valid:" + column_data +
              ". Record(" + record_cnt.to_s  + ") "
          else
            x
          end
        when "internal_status_id"
          x=change_internal_status_to_i(column_data)
          if x.nil?
            raise "Input File Validation Error: Status value not valid:" + column_data +
              ". Record(" + record_cnt.to_s  + ") "
          else
            x
          end
        when "originator_company_id"
          if code_or_name == "C"
            cmp=CmCompany.find(:first, :conditions => ['project_id = ? and code = ?',
              @project_id, column_data])
          else
            cmp=CmCompany.find(:first, :conditions => ['project_id = ? and name = ?',
              @project_id, column_data])
          end
          if cmp.nil?
            raise "Input File Validation Error: Company " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            cmp.id
          end
        when "close_out_id"
          #code or name => name
          clo=CmRidCloseOut.find(:first, :conditions => ['project_id in (?,?) and name = ?',
              0, @project_id, column_data])
          if clo.nil?
            raise "Input File Validation Error: Close Out " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            clo.id
          end
        end
      when "CmReq"
        case column_name
        when "type_id"
          typ=CmReqsType.find(:first, :conditions => ['project_id in (?,?) and name = ?',
              0, @project_id, column_data])
          if typ.nil?
            raise "Input File Validation Error: Type " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            typ.id
          end
        when "classification_id"
          cls=CmReqsClassification.find(:first, :conditions => ['project_id in (?,?) and name = ?',
              0, @project_id, column_data])
          if cls.nil?
            raise "Input File Validation Error: Classification " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            cls.id
          end
        when "status"
          x=change_status_to_i(column_data)
          if x.nil?
            raise "Input File Validation Error: Status value not valid:" + column_data +
              ". Record(" + record_cnt.to_s  + ") "
          else
            x
          end
        when "compliance"
          if column_data.empty?
            return " "
          end
          x=change_compliance_to_i(column_data)
          if x.nil?
            raise "Input File Validation Error: Compliance value not valid:" + column_data +
              ". Record(" + record_cnt.to_s  + ") "
          else
            x
          end
        when "verification_method_id"
          vm=CmTestVerificationMethod.find(:first, :conditions => ['name = ?', column_data])
          if vm.nil?
            raise "Input File Validation Error: Verification Method " + column_data + " not found." +
              " Record(" + record_cnt.to_s  + ") "
          else
            vm.id
          end
        end
      end
    else
      id_to_return
    end #Do not review object
  end

  def create_hash
    new_hash={}

    @columns.each do |col|
      new_hash[col[0]]=""
    end

    return new_hash
  end

end
