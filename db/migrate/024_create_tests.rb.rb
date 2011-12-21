class CreateTests < ActiveRecord::Migration
  #CM/DC Requirements datamodel
  #New column in RIDS table

  
  def self.up

  #Test Type Table
    create_table :cm_test_types, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :level, :integer, :default=> 0, :null => false
      t.column :test_design, :boolean, :default => false, :null => false
      t.column :test_case, :boolean, :default => false, :null => false
      t.column :test_procedure, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end

    #Test Campaign Table 
    create_table :cm_test_campaigns, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 100, :default => "", :null => false
      t.column :description, :text
      t.column :execution_date, :datetime
      t.column :result, :integer
      t.column :auditory, :string
      t.column :assigned_to_id, :integer
      t.column :status, :integer
      #Index to other table.
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :release_id, :integer
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_test_campaigns", ["project_id"], :name => "cm_tests_campaigns_project_id"

    #Test Case/Procedure Table (TC_TP)
    create_table :cm_tests, :force => true do |t|

      #Common parts
      t.column :code, :string, :limit => 30, :null => false
      t.column :name, :string, :limit => 100, :default => "", :null => false
      t.column :version, :string
      t.column :assigned_to_id, :integer
      t.column :status, :integer
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :release_id, :integer
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
      t.column :objective, :text

      t.column :cm_doc_id, :integer
      t.column :type_id, :integer
      t.column :classification_id, :integer
      t.column :cm_test_scenario_id, :integer

      #TP Fields
      t.column :steps_and_checkpoints, :text
      t.column :tools_and_resources, :text
      #TC Fields
      t.column :in_out_specifications, :text
      t.column :pass_fail_criteria, :text  #TD and TC
      t.column :execution, :datetime
      t.column :verification_method, :integer

    end

    add_index "cm_tests", ["project_id"], :name => "cm_tests_project_id"

    #Test Scenario Table (TS)
    create_table :cm_test_scenarios, :force => true do |t|

      t.column :code, :string, :limit => 30, :null => false
      t.column :version, :string
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :environmental_needs, :text
      t.column :special_proc_requirements, :text
      t.column :assigned_to_id, :integer
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_test_scenarios", ["project_id"], :name => "cm_test_scenarios_project_id"

    create_table :cm_test_classifications, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
    end



    create_table :cm_test_records, :force => true do |t|
      t.column :code, :string, :limit => 30, :null => false
      t.column :execution_date, :datetime
      t.column :execution_log, :text
      t.column :execution_evidences , :string
      t.column :result , :integer
      t.column :restrict_or_observe, :text
      t.column :witnessed_by, :integer
      
      t.column :execution_number, :integer, :default => 0, :null => false
      t.column :cm_test_campaigns_object_id, :integer
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end

    add_index "cm_test_records", ["project_id"], :name => "cm_test_records_project_id"
    #add_index "cm_test_records", ["id", "execution_id"], :name => "execution_indx", :unique => true
    
    create_table :cm_tests_tests, :force => true do |t|
      t.column :cm_test_id, :integer, :null => false
      t.column :child_test_id, :integer, :null => false

      t.column :relation_type, :integer
      t.column :created_on, :datetime, :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    add_index "cm_tests_tests", ["cm_test_id", "child_test_id"], :name => "tests_tests_indx", :unique => true


    create_table :cm_tests_objects, :force => true do |t|
      t.column :cm_test_id, :integer, :null => false
      t.column :x_id, :integer, :default => 0, :null => false
      t.column :x_type, :string, :size => 20, :null => false
      t.column :rel_string, :string, :limit => 50, :default => "", :null => false
      t.column :rel_string_2, :string, :default => "", :null => false
      t.column :rel_date, :datetime
      t.column :rel_bool, :boolean, :default => 0,  :null => false
      t.column :target_version_id, :integer
      t.column :category, :integer
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

    create_table :cm_test_campaigns_objects, :force => true do |t|
      t.column :cm_test_campaign_id, :integer, :null => false
      t.column :cm_test_id, :integer, :default => 0, :null => false
      t.column :cm_test_record_id, :integer, :default => 0, :null => false
      t.column :cm_test_scenario_id, :integer, :default => 0, :null => false
      t.column :result, :integer, :default => 0, :null => false
      t.column :execution_order, :integer,:default => 0
      t.column :comments, :text, :default => "", :null => false
      t.column :assigned_to_id, :integer
      t.column :created_on, :datetime, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
    end

  end

  def self.down
    drop_table :cm_test_types
    drop_table :cm_test_campaigns
    drop_table :cm_tests
    drop_table :cm_test_scenarios
    drop_table :cm_test_classifications
    drop_table :cm_test_records
    drop_table :cm_tests_tests
    drop_table :cm_tests_objects
    drop_table :cm_test_campaigns_objects
  end
end
