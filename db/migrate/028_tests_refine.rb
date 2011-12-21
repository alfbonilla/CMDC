class TestsRefine < ActiveRecord::Migration
  def self.up
    #Scenarios Refine
    change_column :cm_test_scenarios, :name, :string, :limit => 100, :default => "", :null => false
    rename_column :cm_test_scenarios, :special_proc_requirements, :starting_conditions

    #New table for verif methods
    create_table :cm_test_verification_methods, :force => true do |t|
      t.column :name, :string, :limit => 30, :default => "", :null => false
      t.column :description, :string, :default => "", :null => false
      t.column :is_default, :boolean, :default => false, :null => false
    end

    CmTestVerificationMethod.create(:name => "Test",
      :description => "Measurement of product performance and functions under representative \
simulated environments", :is_default=> 1)
    CmTestVerificationMethod.create(:name => "Inspection",
      :description => "Visual determination of physical characteristics (constructional \
features, conformance to docs, physical conditions, sw source code coding standards)")
    CmTestVerificationMethod.create(:name => "Analysis",
      :description => "Performing theoretical or empirical evaluation using techniques \
agreed with the Customer (statistics, qualitative design analysis, modelling and computer simulations)")
    CmTestVerificationMethod.create(:name => "Review of Design",
      :description => "Use approved records or evidences that unambiguously show that the requirement is met\
(design docs, design reports, technical descriptions, engineering drawings)")
    CmTestVerificationMethod.create(:name => "Test & Inspection",
      :description => "Combination of the 2 other methods: Test and Inspection")
    
    #Tests refine
    remove_column :cm_tests, :release_id
    remove_column :cm_tests, :execution
    remove_column :cm_tests, :cm_doc_id

    rename_column :cm_tests, :in_out_specifications, :input_data
    add_column :cm_tests, :output_data, :text

    rename_column :cm_tests, :steps_and_checkpoints, :steps
    rename_column :cm_tests, :tools_and_resources, :checkpoints

    remove_column :cm_tests_objects, :category
    remove_column :cm_tests_objects, :target_version_id

    add_column :cm_tests_tests, :execution_order, :integer, :default => 0

    #Campaings rfine
    rename_column :cm_test_campaigns, :execution_date, :start_date

    add_column :cm_test_campaigns, :finish_date, :datetime
    add_column :cm_test_campaigns, :environment, :text

    remove_column :cm_test_campaigns, :result
    remove_column :cm_test_campaigns, :auditory

    rename_column :cm_reqs, :verification_method, :verification_method_id
    rename_column :cm_tempo_reqs, :verification_method, :verification_method_id
  end

  def self.down
    change_column :cm_test_scenarios, :name, :string, :limit => 30, :default => "", :null => false
    rename_column :cm_test_scenarios, :starting_conditions, :special_proc_requirements

    drop_table :cm_test_verification_methods

    add_column :cm_tests, :release_id, :integer
    add_column :cm_tests, :execution, :datetime
    add_column :cm_tests, :cm_doc_id, :integer

    rename_column :cm_tests, :input_data, :in_out_specifications
    remove_column :cm_tests, :output_data

    rename_column :cm_tests, :steps, :steps_and_checkpoints
    rename_column :cm_tests, :checkpoints, :tools_and_resources

    remove_column :cm_tests_tests, :execution_order

    rename_column :cm_test_campaigns, :start_date, :execution_date

    remove_column :cm_test_campaigns, :finish_date
    remove_column :cm_test_campaigns, :environment

    add_column :cm_test_campaigns, :result, :integer

    rename_column :cm_reqs, :verification_method_id, :verification_method
    rename_column :cm_tempo_reqs, :verification_method_id, :verification_method
  end
end
