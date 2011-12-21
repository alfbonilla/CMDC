module CmCommonHelper
  include Redmine::Export::PDF
  # Common method for CM/DC. Return all the objects belonging to the
  # project and subprojects (unless third parm was "false")
  # Parameters:
  # 1. (mandatory) object to find
  # 2. (mandatory) project
  # 3. (optional)  look in subprojects
  # Example: @my_items = get_all_objects(CmItem, @project)
  def get_all_objects(object, project, with_subprojects=true)
    #First Condition, Project_id
    columns = "(#{object.table_name}.project_id = ?"
    values = [project.id]

    if with_subprojects
      #Add a new condition for every subproject
      all_projects = project.children.visible
      all_projects.each do |pr|
        columns << " or #{object.table_name}.project_id = ?"
        values << [pr.id]
      end
    end
    columns << ")"

    conditions = [columns]
    values.each do |value|
      conditions << value
    end

    object.find(:all, :conditions => conditions)
  end

  # Common method for CM/DC. Return 2 strings to be used in
  # searching conditions (columns and values) with the list
  # of projects and subprojects
  # Parameters:
  # 1. (mandatory) object to find
  # 2. (mandatory) project
  # 3. (optional)  look in subprojects
  # Example: columns, values = prepare_get_for_projects(CmItem, @project)
  def prepare_get_for_projects(object, project, query_subp, first_exec)
    #First Condition, Project_id
    with_subp=false
    if Setting.display_subprojects_issues?
      if first_exec.nil?
        with_subp=true
      else
        with_subp=true if query_subp
      end
    end
    
    columns = "(#{object.table_name}.project_id = ?"
    values = [project.id]
   
    if with_subp
      
      #Add a new condition for every subproject
      all_projects = project.children.visible
      all_projects.each do |pr|
        columns << " or #{object.table_name}.project_id = ?"
        values << [pr.id]
      end
    end
    columns << ")"
    
        return columns, values
  end
  
  class CMDCFPDF < ITCPDF
    def initialize(lang, mono="N")
      super(lang)

      if current_language.to_s.downcase == "en"
        if mono=="Y"
          @font_for_content = 'FreeMono'
          @mono='Y'
        else
          @font_for_content = 'FreeSans'
        end
      end
    end

    def SetFontStyle(style, size, my_font='FreeSans')
      SetFont(my_font, style, size)
    end
  end

  def change_compliance_to_s(compliance)
    case compliance
    when 1
      'Compliant'
    when 2
      'Compliant with Assumptions'
    when 3
      'Partially Compliant'
    when 4
      'No Compliant'
    end
  end

  def change_compliance_to_i(compliance)
    case compliance
    when 'Compliant'
      1
    when 'Compliant with Assumptions'
      2
    when 'Partially Compliant'
      3
    when 'No Compliant'
      4
    end
  end

  def change_cmdc_object_to_s(cmdc_obj)
    case cmdc_obj
    when 0
      'All'
    when 1
      'Document'
    when 2
      'Non-Conformance'
    when 3
      'Meeting'
    when 4
      'Change'
    when 5
      'Delivery'
    when 6
      'Item'
    when 7
      'Maintenance'
    when 8
      'Purchase Order'
    when 9
      'Traceability Element'
    when 10
      'Rid'
    when 11
      'Risk'
    when 12
      'SMR'
    when 13
      'Test'
    when 14
      'Test Campaign'
    when 15
      'Test Scenario'
    when 16
      'Test Record'
    when 17
      'Work Around'
    when 18
      'Quality Record'
    when 19
      'Delivery'
    end
  end

  def change_cmdc_object_to_i(cmdc_obj)
    case cmdc_obj
    when 'All'
      0
    when 'Document'
      1
    when 'Non-Conformance'
      2
    when 'Meeting'
      3
    when 'Change'
      4
    when 'Delivery'
      5
    when 'Item'
      6
    when 'Maintenance'
      7
    when 'Purchase Order'
      8
    when 'Traceability Element'
      9
    when 'Rid'
      10
    when 'Risk'
      11
    when 'SMR'
      12
    when 'Test'
      13
    when 'Test Campaign'
      14
    when 'Test Scenario'
      15
    when 'Test Record'
      16
    when 'Work Around'
      17
    when 'Quality Record'
      18
    when 'Delivery'
      19
    end
  end

  #Statuses used by TEs and TESTS
  def change_t_status_to_s(status)
    case status
    when 1
      'Stable'
    when 2
      'Proposed'
    when 3
      'Dismissed'
    end
  end

  def change_t_status_to_i(status)
    case status
    when 'Stable'
      1
    when 'Proposed'
      2
    when 'Dismissed'
      3
    end
  end

  #Use to translate the
  def translate_journal_fields(cm_object,field_name,field_value)

#    logger.error("cm_object -> " + cm_object)
#    logger.error("field_name -> " + field_name)

    if (cm_object.nil? or field_name.nil? or field_value.nil?)
      return ""
    end

    case cm_object
      when 'CmDoc'
        case field_name
          #Types translated in other helpers.
          when 'approval_level'           
            change_approval_level_to_s(field_value)
          when 'baseline'           
            change_baseline_to_s(field_value)
          #Types translated in reference tables:
          when 'category_id'
            DocumentCategory.find(:first,:conditions => ['id=?', field_value]).name unless DocumentCategory.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'type_id'
            CmDocType.find(:first,:conditions => ['id=?', field_value]).name  unless CmDocType.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'originator_company_id'
            CmCompany.find(:first,:conditions => ['id=?', field_value]).name unless CmCompany.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'subsystem_id'
            CmSubsystem.find(:first,:conditions => ['id=?', field_value]).name unless CmSubsystem.find(:first,:conditions => ['id=?', field_value]).nil?
          else
            field_value
        end

      when 'CmNc'
        case field_name
          #Types translated in reference tables:
          when 'status_id'
            CmNcsStatus.find(:first,:conditions => ['id=?', field_value]).name unless CmNcsStatus.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'type_id'
            CmNcsType.find(:first,:conditions => ['id=?', field_value]).name  unless CmNcsType.find(:first,:conditions => ['id=?', field_value]).nil?            
          when 'classification_id'
            CmNcsClassification.find(:first,:conditions => ['id=?', field_value]).name unless CmNcsClassification.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'subsystem_id'
            CmSubsystem.find(:first,:conditions => ['id=?', field_value]).name unless CmSubsystem.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'assigned_to_id'
            unless (User.find(:first,:conditions => ['id=?', field_value]).nil?)
              User.find(:first,:conditions => ['id=?', field_value]).firstname + " " +User.find(:first,:conditions => ['id=?', field_value]).lastname
            end
          when 'rlse_expected_id'
            Version.find(:first,:conditions => ['id=?', field_value]).name unless Version.find(:first,:conditions => ['id=?', field_value]).nil?
          when  'supplier_id'
            CmCompany.find(:first,:conditions => ['id=?', field_value]).name unless CmCompany.find(:first,:conditions => ['id=?', field_value]).nil?
        else
            field_value
        end

     when 'CmRid'
        case field_name
          #Types translated in other helpers.
          when 'internal_status_id'
            change_internal_status_to_s(field_value.to_i)
          when 'category'
           change_category_to_s(field_value.to_i)
           #Types translated in reference tables:
          when 'close_out_id'
            CmRidCloseOut.find(:first,:conditions => ['id=?', field_value]).name unless CmRidCloseOut.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'implementation_release_id'
            Version.find(:first,:conditions => ['id=?', field_value]).name unless Version.find(:first,:conditions => ['id=?', field_value]).nil?
          when 'assigned_to_id'
            unless (User.find(:first,:conditions => ['id=?', field_value]).nil?)
              User.find(:first,:conditions => ['id=?', field_value]).firstname + " " +User.find(:first,:conditions => ['id=?', field_value]).lastname
            end
          when 'affected_doc_id'
            CmDoc.find(:first,:conditions => ['id=?', field_value]).name unless CmDoc.find(:first,:conditions => ['id=?', field_value]).nil?
          else
            field_value
        end

    else

      field_value

    end
    
  end


end