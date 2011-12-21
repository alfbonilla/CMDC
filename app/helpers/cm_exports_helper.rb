module CmExportsHelper

  def get_model_name(column_name, object_exp)

    #Included values for Cm_Delivery, Cm_Item, Cm_Change, Cm_Purchase_Order
    #                    Cm_Doc, Cm_Board, Cm_Nc, Cm_Rid, Cm_Smr, Cm_Wa
    case column_name
    when "status_id", "type_id", "author_id", "category_id", "classification_id", "project_id",
         "vendor_id", "supplier_id", "affected_doc_id", "release_id", "affected_item_id", "company_id",
         "phase_id", "rlse_detected_id", "rlse_solved_id", "rlse_verified_id", "close_out_id",
         "open_release_id", "originator_company_id", "implementation_release_id", "rlse_removed_id",
         "subsystem_id", "verification_method_id", "rlse_expected_id"

         if column_name == "originator_company_id" and object_exp == "CmDoc"
           "company"
         else
           column_name.slice(0, column_name.index('_id'))
         end

    when "cm_doc_id"
      if object_exp == "CmChange"
        "change_doc"
      end

    when "to_company"
      "target_company"

    when "from_company"
      "source_company"

    when "assigned_to_id"
      "assignee"

    when "approved_by"
      "approver"

    when "cm_item_group_id"
      "group"

    when "cm_nc_id"
      "nonConformance"

    when "cm_change_id"
      "change"

    else
      logger.error("[CMDC Error]>Column not controlled" + column_name)

    end

  end

end