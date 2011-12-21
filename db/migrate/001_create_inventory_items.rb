class CreateInventoryItems < ActiveRecord::Migration
  #This script re-creates ALL the tables of the plugin, deleting ALL the data
  #It has an update for all the rows inserted, setting the project as project_id = '4'
  def self.up
    create_table :cm_items, :force => true do |t|
      t.column :code, :string, :limit => 50, :null => false
      t.column :product_tree_code, :string, :limit => 50, :default => "", :null => false
      t.column :quantity, :integer, :default => 1
      t.column :available_qty, :integer, :default => 1
      t.column :name, :string, :default => "", :null => false
      t.column :description, :text
      t.column :category_id, :integer
      t.column :cm_item_group_id, :integer
      t.column :status_id, :integer
      t.column :type_id, :integer
      t.column :classification_id, :integer
      t.column :configuration_item, :boolean
      t.column :version, :string
      t.column :serial_number, :string
      t.column :model_number, :string
      t.column :physical_location, :string
      t.column :installed_on_host, :string
      t.column :expiration_date, :datetime
      t.column :comments_on_license, :text
      t.column :comments, :text
      t.column :markings, :string
      t.column :external_info, :string
      t.column :frame_contract, :boolean
      t.column :actual_estimated, :boolean
      t.column :item_owner, :string
      t.column :disposal_method, :string
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_items", ["project_id"], :name => "cm_items_project_id"
        
    create_table :cm_item_statuses, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_closed, :boolean, :default => false, :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_item_types, :force => true do |t|
      t.column :name, :string, :limit => 20, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_item_categories, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_item_groups, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_item_classifications, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end
    
    create_table :cm_items_issues, :force => true do |t|
      t.column :cm_item_id, :integer, :null => false
      t.column :issue_id, :integer, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_items_issues", ["issue_id", "cm_item_id"], :name => "items_issues_indx", :unique => true

    create_table :cm_items_items, :force => true do |t|
      t.column :cm_item_id, :integer, :null => false
      t.column :child_item_id, :integer, :null => false
      t.column :relation_type, :string, :limit => 20, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_items_items", ["cm_item_id", "child_item_id"], :name => "items_items_indx", :unique => true

    # Purchase Orders Data Model
    create_table :cm_purchase_orders, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :title, :string, :limit => 100
      t.column :requested_by, :string, :limit => 30
      t.column :requested_date, :date
      t.column :authorized_by, :string, :limit => 30
      t.column :authorized_date, :date
      t.column :purchase_date, :date
      t.column :supplier_id, :integer
      t.column :vendor_id, :integer
      t.column :total_payment, :decimal, :precision => 15, :scale => 2
      t.column :payment_period, :string
      t.column :payment_method, :string
      t.column :VAT_included, :integer, :default => 0
      t.column :leadtime, :datetime
      t.column :delivery_note, :string
      t.column :budget, :string, :limit => 50
      t.column :review_leadtime, :boolean, :default => false, :null => false
      t.column :comments, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime      
    end

    add_index "cm_purchase_orders", ["project_id"], :name => "cm_purchase_orders_project_id"

    create_table :cm_po_details, :force => true do |t|
      t.column :cm_purchase_order_id, :integer, :default => 0, :null => false
      t.column :cm_item_id, :integer, :default => 0, :null => false
      t.column :quantity, :integer, :default => 0, :null => false
      t.column :cost_per_unit, :decimal, :precision => 15, :scale => 2, :default => 0
      t.column :VAT_included, :boolean, :default => false, :null => false
      t.column :reception_date, :datetime
      t.column :comments, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_po_details", ["cm_purchase_order_id", "cm_item_id"], :name => "po_details_indx", :unique => true
    
    create_table :cm_companies, :force => true do |t|
      t.column :code, :string, :limit => 10, :default => "", :null => false
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :company_type, :string, :limit => 20, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :address, :string, :default => ""
      t.column :technical_contact, :string, :limit => 50, :default => ""
      t.column :distributor_name, :string, :limit => 50, :default => ""
      t.column :phone, :string, :limit => 30, :default => ""
      t.column :fax, :string, :limit => 30, :default => ""
      t.column :mail, :string, :limit => 60
      t.column :web_site, :string, :limit => 100
      t.column :project_id, :integer, :default => 0, :null => false
    end

    # Maintenance Tables
    create_table :cm_mnt_logs, :force => true do |t|
      t.column :cm_item_id, :integer, :default => 0, :null => false
      t.column :name, :string, :limit => 50, :default => ""
      t.column :type_id, :integer
      t.column :status_id, :integer
      t.column :nc_ref, :string      
      t.column :process_used, :string      
      t.column :maintained_by_id, :integer, :default => 0, :null => false
      t.column :maintenance_start_date, :datetime
      t.column :maintenance_time, :decimal
      t.column :physical_location, :string
      t.column :installation_log, :text
      t.column :configuration_comments, :text     
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_mnt_logs", ["project_id"], :name => "cm_mnt_logs_project_id"

    create_table :cm_mnt_log_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end 

    create_table :cm_mnt_log_statuses, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end     
   
    # Document Data Model
    create_table :cm_docs, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 255, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :version, :string, :limit => 10, :default => "", :null => false
      t.column :type_id, :integer, :null => false
      t.column :status_id, :integer, :null => false
      t.column :category_id, :integer, :null => false
      t.column :applicable, :boolean, :default => false
      t.column :applicable_to, :integer, :default => 0, :null => false
      t.column :physical_location, :string, :default => "", :null => false
      t.column :approved_date, :datetime
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
      t.column :project_id, :integer, :default => 0, :null => false
    end

    add_index "cm_docs", ["project_id"], :name => "cm_docs_project_id"

    create_table :cm_doc_counters, :force => true do |t|
      t.column :name, :string
      t.column :format, :text
      t.column :counter, :integer, :default => 0, :null => false
      t.column :increment_by, :integer, :default => 1, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_doc_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :pattern, :string, :limit => 100, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_doc_statuses, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    # Non-Conformances Data Model
    create_table :cm_ncs, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :type_id, :integer, :null => false
      t.column :name, :string, :limit => 100, :default => "", :null => false
      t.column :status_id, :integer
      t.column :closing_date, :datetime
      t.column :description, :text
      t.column :phase_id, :integer
      t.column :classification_id, :integer
      t.column :company_id, :integer
      t.column :cm_item_group_id, :integer
      t.column :failure_tests, :text
      t.column :violated_reqs, :text
      t.column :analysis, :text
      t.column :reproducibility, :boolean, :default => false
      t.column :steps_to_reproduce, :text
      t.column :affected_items, :text
      t.column :related_docs, :text
      t.column :critical_item, :boolean, :default => false
      t.column :safety_item, :boolean, :default => false
      t.column :analyzed_on, :datetime
      t.column :supplier_id, :integer
      t.column :rlse_detected_id, :integer
      t.column :rlse_solved_id, :integer
      t.column :rlse_verified_id, :integer
      t.column :rlse_detected_info, :string
      t.column :rlse_solved_info, :string
      t.column :rlse_verified_info, :string
      t.column :assigned_to_id, :integer, :default => 0, :null => false
      t.column :cm_qr_id, :integer, :default => 0, :null => false
      t.column :documentation_problem, :boolean, :default => false
      t.column :detected_on, :string
      t.column :rfw_reference, :string
      t.column :affected_design, :text
      t.column :design_changes_done, :boolean, :default => 0,  :null => false
      t.column :priority, :string, :limit => 30, :default => "", :null => false
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_ncs", ["project_id"], :name => "cm_ncs_project_id"

    create_table :cm_ncs_ncs, :force => true do |t|
      t.column :cm_nc_id, :integer, :null => false
      t.column :child_nc_id, :integer, :null => false
      t.column :created_on, :datetime, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_ncs_ncs", ["cm_nc_id", "child_nc_id"], :name => "ncs_ncs_indx", :unique => true

    create_table :cm_ncs_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :level, :integer, :default=> 0, :null => false
      t.column :relate_smrs, :boolean, :default => 0, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_ncs_statuses, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_closed, :boolean, :default => false, :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_ncs_phases, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_ncs_classifications, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_ncs_objects, :force => true do |t|
      t.column :cm_nc_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 30, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    create_table :cm_smrs, :force => true do |t|
      t.column :smr_code, :string, :limit => 30, :null => false
      t.column :cm_nc_id, :integer, :default => 0, :null => false
      t.column :cm_change_id, :integer, :default => 0, :null => false
      t.column :description, :text
      t.column :specific_tests, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_smrs", ["project_id"], :name => "cm_smrs_project_id"

    create_table :cm_boards, :force => true do |t|
      t.column :cm_board_code, :string, :limit => 30, :null => false
      t.column :subject, :string, :limit => 100, :default => "", :null => false
      t.column :meeting_date, :datetime, :null => false
      t.column :type_id, :string, :limit => 10, :null => false
      t.column :company_id, :integer, :default => 0, :null => false
      t.column :participants, :text
      t.column :board_body, :text
      t.column :conclusions, :text
      t.column :distribution_list, :text
      t.column :action_counter, :integer, :default => 0, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_boards", ["project_id"], :name => "cm_boards_project_id"

    create_table :cm_board_types, :force => true do |t|
      t.column :name, :string, :limit => 20, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_boards_issues, :force => true do |t|
      t.column :cm_board_id, :integer, :null => false
      t.column :issue_id, :integer, :null => false
      t.column :created_on, :datetime, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_boards_issues", ["issue_id", "cm_board_id"], :name => "cm_boards_issues_indx", :unique => true

    create_table :cm_was, :force => true do |t|
      t.column :cm_wa_code, :string, :limit => 30, :null => false
      t.column :cm_nc_id, :integer, :default => 0, :null => false
      t.column :status, :string, :limit => 11, :null => false
      t.column :wa_type, :string, :limit => 25, :null => false
      t.column :rlse_removed_id, :integer
      t.column :description, :text
      t.column :affected_items, :text
      t.column :constraints, :text
      t.column :comments, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_was", ["project_id"], :name => "cm_was_project_id"

    create_table :cm_qrs, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :status, :string, :null => false
      t.column :type_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_name, :string, :size => 50, :null => false
      t.column :assigned_to_id, :integer, :default => 0, :null => false
      t.column :check_used, :string
      t.column :ref_docs, :text
      t.column :comments, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_qrs", ["project_id"], :name => "cm_qrs_project_id"
    add_index "cm_qrs", ["x_id"], :name => "cm_qrs_x_id"

    create_table :cm_qr_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :template, :string, :default => "", :null => false
    end

    create_table :cm_deliveries, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 50, :default => "", :null => false
      t.column :description, :text, :null => false
      t.column :delivery_date, :datetime
      t.column :release_id, :integer
      t.column :status_id, :integer
      t.column :from_company, :integer
      t.column :to_company, :integer
      t.column :approved_by, :integer
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_deliveries", ["project_id"], :name => "cm_deliveries_project_id"

    create_table :cm_deliveries_objects, :force => true do |t|
      t.column :cm_delivery_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 30, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    create_table :cm_delivery_statuses, :force => true do |t|
      t.column :name, :string, :limit => 50, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_smrs_affected_files, :force => true do |t|
      t.column :cm_smr_id, :integer, :default => 0, :null => false
      t.column :file_name, :string, :default => "", :null => false
      t.column :source_revision, :string, :limit => 10, :null => false
      t.column :final_revision, :string, :limit => 10, :null => false
      t.column :comments_on_smr, :text
      t.column :approved, :boolean, :default => false
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    create_table :cm_source_files, :force => true do |t|
      t.column :file_name, :string, :default => "", :null => false
      t.column :revision_at_load, :string, :limit => 10, :default => "Not Loaded",:null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    add_index "cm_source_files", ["project_id"], :name => "cm_source_files_project_id"

    create_table :cm_changes, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 50, :default => "", :null => false
      t.column :status_id, :integer
      t.column :type_id, :integer
      t.column :from_company, :integer
      t.column :to_company, :integer
      t.column :recep_deliv_date, :datetime
      t.column :due_date, :datetime
      t.column :classification, :integer
      t.column :compatibility, :integer
      t.column :cm_doc_id, :integer
      t.column :affected_doc_id, :integer
      t.column :affected_integrated_version, :string, :limit => 10, :null => false
      t.column :affected_item_id, :integer
      t.column :reason, :text
      t.column :description, :text
      t.column :release_id, :integer
      t.column :implementation, :integer
      t.column :applicable_version, :string, :limit => 50, :default => "", :null => false
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_changes", ["project_id"], :name => "cm_changes_project_id"

    create_table :cm_changes_changes, :force => true do |t|
      t.column :parent_change_id, :integer, :null => false
      t.column :child_change_id, :integer, :null => false
      t.column :relation_type, :integer
      t.column :description, :string, :default => "", :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    create_table :cm_changes_versions, :force => true do |t|
      t.column :cm_change_id, :integer, :null => false
      t.column :version, :string, :limit => 50, :default => "", :null => false
      t.column :applicable, :boolean, :default => 0,  :null => false
      t.column :updated_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :comments, :string
    end

    create_table :cm_change_statuses, :force => true do |t|
      t.column :name, :string, :limit => 50, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :is_closed, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_change_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_changes_objects, :force => true do |t|
      t.column :cm_change_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 30, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end


    create_table :cm_rids, :force => true do |t|
      t.column :code, :string, :null => false
      t.column :name, :string, :default => "", :null => false
      t.column :internal_status_id, :integer
      t.column :external_status_id, :integer
      t.column :open_release_id, :integer
      t.column :originator, :string
      t.column :originator_company_id, :integer
      t.column :affected_doc_id, :integer
      t.column :affected_doc_version, :string, :limit => 25, :null => false
      t.column :problem_location, :string, :null => false
      t.column :discrepancy, :text
      t.column :recommendation, :text
      t.column :disposition, :text
      t.column :author_response, :text
      t.column :close_out_id, :integer
      t.column :doc_due_date, :datetime
      t.column :generation_date, :datetime
      t.column :implementation_release_id, :integer
      t.column :comments, :text
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_rids", ["project_id"], :name => "cm_rids_project_id"

    create_table :cm_rids_issues, :force => true do |t|
      t.column :cm_rid_id, :integer, :null => false
      t.column :issue_id, :integer, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :updated_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_rids_issues", ["issue_id", "cm_rid_id"], :name => "rids_issues_indx", :unique => true

    create_table :cm_rid_close_outs, :force => true do |t|
      t.column :name, :string, :limit => 50, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :is_closed, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_risks, :force => true do |t|
      t.column :code, :string, :limit => 50, :null => false
      t.column :name, :string, :default => "", :null => false
      t.column :status_id, :integer
      t.column :type_id, :integer
      t.column :impact, :integer
      t.column :probability, :integer
      t.column :priority_ranking, :integer
      t.column :risk_exposure, :integer
      t.column :detection_date, :date
      t.column :closing_date, :date
      t.column :description, :text
      t.column :mitigation, :text
      t.column :assigned_to_id, :integer, :default => 0, :null => false
      t.column :comments, :text
      t.column :impact_ini_date, :date
      t.column :impact_end_date, :date
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_risks", ["project_id"], :name => "cm_risks_project_id"

    create_table :cm_risk_statuses, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_closed, :boolean, :default => false, :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_risk_types, :force => true do |t|
      t.column :name, :string, :limit => 20, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    create_table :cm_risks_issues, :force => true do |t|
      t.column :cm_risk_id, :integer, :null => false
      t.column :issue_id, :integer, :null => false
      t.column :created_on, :datetime, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_risks_issues", ["issue_id", "cm_risk_id"], :name => "cm_risks_issues_indx", :unique => true

  end

  def self.down
    drop_table :cm_items
    drop_index :cm_items_project_id
    drop_table :cm_item_statuses
    drop_table :cm_item_types
    drop_table :cm_item_categories
    drop_table :cm_item_groups
    drop_table :cm_item_classifications
    drop_table :cm_items_issues
    drop_table :cm_purchase_orders
    drop_table :cm_po_details
    drop_table :cm_mnt_logs
    drop_table :cm_mnt_log_types
    drop_table :cm_mnt_log_statuses
    drop_table :cm_docs
    drop_table :cm_doc_statuses
    drop_table :cm_doc_types
    drop_table :cm_doc_counters
    drop_table :cm_ncs
    drop_table :cm_ncs_ncs
    drop_table :cm_ncs_types
    drop_table :cm_ncs_statuses
    drop_table :cm_ncs_phases
    drop_table :cm_ncs_classifications
    drop_table :cm_ncs_objects
    drop_table :cm_companies
    drop_table :cm_boards
    drop_table :cm_boards_issues
    drop_table :cm_was
    drop_table :cm_qrs
    drop_table :cm_qr_types
    drop_table :cm_deliveries
    drop_table :cm_deliveries_objects
    drop_table :cm_deliveries_statuses
    drop_table :cm_smr_affected_files
    drop_table :cm_source_files
    drop_table :cm_changes
    drop_table :cm_changes_changes
    drop_table :cm_changes_versions
    drop_table :cm_change_statuses
    drop_table :cm_change_types
    drop_table :cm_rids
    drop_table :cm_rids_issues
    drop_table :cm_rid_close_outs
    drop_table :cm_risks
    drop_table :cm_risk_statuses
    drop_table :cm_risk_types
    drop_table :cm_risks_issues
  end
end
