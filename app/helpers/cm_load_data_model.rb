#!/usr/bin/env ruby
#
# Load the redmine database CM/DC reference tables. Format
#
# cm_load_data_model DELETE|KEEP
#
# RAILS_ENV=production ruby script/runner vendor/plugins/redmine_cm/app/helpers/cm_load_data_model.rb DELETE
#
#require "mysql"
require "active_record"

puts "CM/DC Load Data Model Script"
puts ""
puts "-This scripts load the default data for the reference tables in the RAILS_ENV environment"
puts "-Script release adapted for CMDC 1.2r286 in ahead. Previous releases will fail"

#Treat input parms
if ARGV.length != 1
  puts "Wrong Number of args:" + ARGV.length.to_s
  puts "Command help:"
  puts "cm_load_data_model DELETE|KEEP"
  puts ">> DELETE: delete all records in RTs with received project"
  puts ">> KEEP: do not delete records in RTs with received project"
  Process.exit(99)
end

proj=0
delete=ARGV[0]

if delete == "DELETE"
  delete = "Yes"
else
  delete = "No"
end

puts ""

ActiveRecord::Base.logger = Logger.new(STDERR)

environment=ENV['RAILS_ENV'].to_s
puts "RAILS_ENV variable value:" + environment

config = Rails::Configuration.new
database = config.database_configuration[environment]
if database.nil?
  puts "Database info not found for environment " + environment + "!!"
  Process.exit(90)
end

puts "Load Info"
puts ">> Database(localhost): " + database["database"]
puts ">> Database Port      : " + database["port"].to_s
puts ">> Delete Records     : " + delete
puts "Continue (Yes/No)?"
continue_answer=STDIN.gets.chomp

if continue_answer != "Yes"
  puts "Process cancelled by user"
  Process.exit(98)
end

if delete == "Yes"
  puts "- Deleting all the records for project " + proj.to_s + ", plus QRs and Verification Methods..."
  CmItemStatus.delete_all(:project_id => proj)
  CmItemType.delete_all(:project_id => proj)
  CmItemClassification.delete_all(:project_id => proj)
  CmItemGroup.delete_all(:project_id => proj)
  CmItemCategory.delete_all(:project_id => proj)
  CmCompany.delete_all(:project_id => proj)
  CmMntLogType.delete_all(:project_id => proj)
  CmMntLogStatus.delete_all(:project_id => proj)
  CmDocType.delete_all(:project_id => proj)
  CmDocStatus.delete_all(:project_id => proj)
  CmNcsType.delete_all(:project_id => proj)
  CmNcsStatus.delete_all(:project_id => proj)
  CmNcsPhase.delete_all(:project_id => proj)
  CmNcsClassification.delete_all(:project_id => proj)
  CmBoardType.delete_all(:project_id => proj)
  CmDeliveryStatus.delete_all(:project_id => proj)
  CmDocCounter.delete_all(:project_id => proj)
  CmReqsType.delete_all(:project_id => proj)
  CmReqsClassification.delete_all(:project_id => proj)
  CmTestVerificationMethod.delete_all
  CmQrType.delete_all
  CmChangeStatus.delete_all(:project_id => proj)
  CmChangeType.delete_all(:project_id => proj)
end

puts "- Creating item statuses..."

#begin
CmItemStatus.new(:name => "In evaluation", :description => "Item being evaluated before purchase and reception", :is_default => 1, :project_id => proj)
CmItemStatus.create(:name => "Purchased", :description => "Item purchased but not at DMS premises yet", :project_id => proj)
CmItemStatus.create(:name => "In transit", :description => "Item being delivered to customer or being received from supplier", :project_id => proj)
CmItemStatus.create(:name => "OK", :description => "Item is allocated in DMS premises and working correctly", :project_id => proj)
CmItemStatus.create(:name => "Malfunction", :description => "Item is installed but not working correctly", :project_id => proj)
CmItemStatus.create(:name => "Expired", :description => "Item is installed but its license is expired", :project_id => proj)
CmItemStatus.create(:name => "Sent for repairs", :description => "Item has been sent to supplier for repairs/replacement", :project_id => proj)
CmItemStatus.create(:name => "Delivered", :description => "Item has been successfully delivered to customer", :project_id => proj)
CmItemStatus.create(:name => "Under Construction", :description => "Item currently under development or construction", :project_id => proj)

puts "- Creating item types..."

CmItemType.create(:name => "Stock", :acronym => "STC",  :description => "Item used for controlling single-items availability, giving common item descriptions and so on...", :project_id => proj)
CmItemType.create(:name => "Single", :acronym => "SGL", :description => "Individual item. It can be integrated in, installed in or belongs to another item", :project_id => proj)

puts "- Creating item classifications..."

CmItemClassification.create(:name => "None", :description => "LI4 information not required", :is_default => true, :project_id => proj)
CmItemClassification.create(:name => "Class 1", :description => "Consumable items (parts, materials, supplies, etc.) acquired by the Subcontractor", :project_id => proj)
CmItemClassification.create(:name => "Class 2", :description => "Consumable items (parts, materials, supplies, etc.) furnished by the GMS Segment Contractor", :project_id => proj)
CmItemClassification.create(:name => "Class 3", :description => "Capital items/production support equipment and tools acquired by the Subcontractor", :project_id => proj)
CmItemClassification.create(:name => "Class 4", :description => "Capital items/production support equipment and tools furnished by the GMS Segment Contractor", :project_id => proj)
CmItemClassification.create(:name => "Class 5", :description => "Items purchased by the Subcontractor and/or its Sub-contractors on their own account but amortised under the Contract", :project_id => proj)

puts "- Creating item groups..."

CmItemGroup.create(:name => "Generic Project Item", :description => "All those items without any other specific qualification", :is_default => 1, :project_id => proj)
CmItemGroup.create(:name => "Development Item", :description => "Item associated to the development environment and tasks of the project", :is_default => 0, :project_id => proj)
CmItemGroup.create(:name => "Test Item", :description => "Item associated to the test environment and tasks of the project", :is_default => 0, :project_id => proj)

puts "- Creating item categories..."

CmItemCategory.create(:name => "SW PROJ", :description => "Software generated/delivered by the project (including tests, tools...)", :is_default => 1, :project_id => proj)
CmItemCategory.create(:name => "HW PROJ", :description => "Hardware generated/delivered by the project", :project_id => proj)
CmItemCategory.create(:name => "SW COTS", :description => "Operational SW COTS", :project_id => proj)
CmItemCategory.create(:name => "HW COTS", :description => "Operational HW COTS", :project_id => proj)
CmItemCategory.create(:name => "SW CFI", :description => "Software received from the customer", :project_id => proj)
CmItemCategory.create(:name => "HW CFI", :description => "Hardware received from the customer", :project_id => proj)

puts "- Creating DMS company..."

CmCompany.create(:name => "Deimos Space", :code => "DMS", :company_type => "home", :description => "", :project_id => proj)

puts "- Creating maintenance types..."

CmMntLogType.create(:name => "First Installation", :description => "Tasks performed during the first installation of the item", :project_id => proj)
CmMntLogType.create(:name => "Upgrade", :description => "Tasks performed upgrading an already installed item", :project_id => proj)
CmMntLogType.create(:name => "Patch", :description => "Tasks performed patching an already installed item for solving an error", :project_id => proj)
CmMntLogType.create(:name => "Delete", :description => "Tasks performed deleting an already installed item", :project_id => proj)

puts "- Creating maintenance statuses..."

CmMntLogStatus.create(:name => "Deferred", :description => "Maintenance deferred", :is_default => false, :project_id => proj)
CmMntLogStatus.create(:name => "Ok", :description => "Maintenance completed succesfully", :is_default => false, :project_id => proj)
CmMntLogStatus.create(:name => "Error", :description => "Maintenance finished with errors", :is_default => false, :project_id => proj)
CmMntLogStatus.create(:name => "Ongoing", :description => "Maintenance ongoing", :is_default => false, :project_id => proj)
CmMntLogStatus.create(:name => "Scheduled", :description => "Maintenance scheduled to some date", :is_default => true, :project_id => proj)
CmMntLogStatus.create(:name => "Use as Is", :description => "Maintenance not completed because of some reasons. Item will be used as is", :is_default => false, :project_id => proj)

puts "- Creating doc types..."

CmDocType.create( :name => "Minutes of Meeting", :acronym => "MOM", :description => "Final document with the details of a meeting", :project_id => proj)
CmDocType.create( :name => "Fax", :acronym => "FAX", :description => "Faxes", :project_id => proj)
CmDocType.create( :name => "User Manual", :acronym => "SUM", :description => "User Manuals", :project_id => proj)
CmDocType.create( :name => "External Document", :acronym => "EXT", :description => "Documents coming from outside of the project that are considered important to account them into the CMDC", :project_id => proj)
CmDocType.create( :name => "Management Plan", :acronym => "MP", :description => "Management Plan (PM, PA, CM)", :project_id => proj)
CmDocType.create( :name => "Generic Project Document", :acronym => "GEN", :description => "Those project documents that do not match in other specified types", :is_default => 1 , :project_id => proj)
CmDocType.create( :name => "User Requirements", :acronym => "URD", :description => "User Requirements Documentation", :project_id => proj)
CmDocType.create( :name => "System Requirements", :acronym => "SRD", :description => "System Requirements Documentation", :project_id => proj)
CmDocType.create( :name => "Technical Note", :acronym => "TNO", :description => "Technical Note", :project_id => proj)
CmDocType.create( :name => "Memorandum", :acronym => "MEM", :description => "Memorandum", :project_id => proj)
CmDocType.create( :name => "Tech Specification", :acronym => "TSP", :description => "Technical Specification", :project_id => proj)
CmDocType.create( :name => "Progress Report", :acronym => "PRR", :description => "Project Management Reports used to inform to the customer about the project status in a regular base, monthly, bimonthly, etc", :project_id => proj)
CmDocType.create( :name => "Delivery Note", :acronym => "DRN", :description => "Delivery Note", :project_id => proj)
CmDocType.create( :name => "Handout", :acronym => "HAO", :description => "Handouts for presentations", :project_id => proj)
CmDocType.create( :name => "Review Plan", :acronym => "RPL", :description => "Review Plan", :project_id => proj)
CmDocType.create( :name => "PA Report", :acronym => "PAR", :description => "Product Assourance Report", :project_id => proj)
CmDocType.create( :name => "Architectural Design", :acronym => "ADD", :description => "Architecture Design Document", :project_id => proj)
CmDocType.create( :name => "Proposal Documentation", :acronym => "PRO", :description => "Documents related to the proposals or small proposals", :project_id => proj)
CmDocType.create( :name => "Detailed Design", :acronym => "DDD", :description => "Detailed Design Document", :project_id => proj)

puts "- Creating doc statuses..."

CmDocStatus.create( :name => "Draft", :description => "Document is being created or modified", :is_default => 1 , :project_id => proj)
CmDocStatus.create( :name => "Pending Review", :description => "Document created or modified, waiting for some further revision or authorization", :project_id => proj)
CmDocStatus.create( :name => "Pending Approval", :description => "Document reviewed", :is_closed => 1, :project_id => proj)
CmDocStatus.create( :name => "Reviewed, Pending Rework", :description => "Document does not satisfy revision or authorization processes", :project_id => proj)
CmDocStatus.create( :name => "Published", :description => "Document authorized and published", :is_closed => 1, :project_id => proj)
CmDocStatus.create( :name => "Received", :description => "Document received from external sources", :is_received=> 1, :project_id => proj)

puts "- Creating NC types..."

CmNcsType.create(:name => "NCR", :acronym => "NCR", :description => "NCR is the most general document, generated when any non-conformance at element level is detected. These reports are used to notify non-fulfillment of a requirement", :is_default => 1, :level => 1, :project_id => proj)
CmNcsType.create(:name => "SPR", :acronym => "SPR", :description => "SPR belongs to some NCR (except those cases where is found by inspection, integration or subcontractor", :level => 2, :project_id => proj)

puts "- Creating NC statuses..."

CmNcsStatus.create(:name => "Open", :description => "At the moment the error is found (tests performed at element level) ", :is_default => 1, :project_id => proj)
CmNcsStatus.create(:name => "Analyzed", :description => "Problem is analysed", :project_id => proj)
CmNcsStatus.create(:name => "Implemented", :description => "Author considers solution is ready to be validated and verified", :project_id => proj)
CmNcsStatus.create(:name => "Imp.for Verification", :description => "When new internal sw release is delivered to V&V, allowing them selecting the NCs to be tested", :project_id => proj)
CmNcsStatus.create(:name => "For Closure", :description => "The NC has been fixed according to the verification process", :project_id => proj)
CmNcsStatus.create(:name => "Closed", :description => "Closed at the NRB or CCB", :is_closed => 1, :project_id => proj)
CmNcsStatus.create(:name => "Rejected", :description => "Author rejects the finding", :project_id => proj)
CmNcsStatus.create(:name => "Withdrawn", :description => "When the originator agrees with the rejection", :is_closed => 1, :project_id => proj)
CmNcsStatus.create(:name => "Ext. Implemented", :description => "(Just for SPRs) The subcontractor has delivered a new release and reports the implementation", :project_id => proj)
CmNcsStatus.create(:name => "Deferred", :description => "Resolution is delayed in time", :project_id => proj)

puts "- Creating NC phases..."

CmNcsPhase.create(:name => "Design", :description => "Non-conformance found at design phase", :is_default => 0, :project_id => proj)
CmNcsPhase.create(:name => "Inspection", :description => "Non-conformance internally found at inspection phase", :is_default => 0, :project_id => proj)
CmNcsPhase.create(:name => "Integration", :description => "Non-conformance found at integration phase", :is_default => 0, :project_id => proj)
CmNcsPhase.create(:name => "Manufacturing", :description => "Non-conformance found at manufacturing phase", :is_default => 0, :project_id => proj)
CmNcsPhase.create(:name => "Test", :description => "Non-conformance found at test phase", :is_default => 1, :project_id => proj)
CmNcsPhase.create(:name => "Maintenance", :description => "Non-conformance found in product delivered to customer", :is_default => 1, :project_id => proj)

puts "- Creating NC classifications..."

CmNcsClassification.create(:name => "Minor", :description => "Minor non-conformance found", :is_default => 1, :project_id => proj)
CmNcsClassification.create(:name => "Major", :description => "Major non-conformance found", :project_id => proj)
CmNcsClassification.create(:name => "Safety", :description => "Safety non-conformance found", :project_id => proj)

puts "- Creating board types..."

CmBoardType.create( :name => "Internal CCB", :acronym => "ICCB", :description => "Internal Change Control Board", :is_default => 1 , :project_id => proj)
CmBoardType.create( :name => "Internal NRB", :acronym => "INRB", :description => "Internal Non-Conformances Review Board", :project_id => proj)
CmBoardType.create( :name => "External CCB", :acronym => "CCB", :description => "Change Control Board with customer(s)", :project_id => proj)
CmBoardType.create( :name => "External NRB", :acronym => "NRB", :description => "Non-Conformances Review Board with customer(s)", :project_id => proj)
CmBoardType.create( :name => "Technical Meeting", :acronym => "TM", :description => "Internal Technical Meeting. Technical Purpose. The customer is not involved in this meeting.", :project_id => proj)
CmBoardType.create( :name => "External Generic M", :acronym => "EXT", :description => "Meetings with customers, suppliers, etc...", :project_id => proj)
CmBoardType.create( :name => "Internal PM", :acronym => "IPM", :description => "Progress Meeting with the team. The customer is not involved in that meetings", :project_id => proj)
CmBoardType.create( :name => "Weekly Follow-up", :acronym => "WF", :description => "Weekly progress meeting", :project_id => proj)
CmBoardType.create( :name => "Kick-Off Meeting", :acronym => "KOM", :description => "Kick-Off Meeting", :project_id => proj)
CmBoardType.create( :name => "Progress Meeting", :acronym => "PM", :description => "Progress Meeting", :project_id => proj)

puts "- Creating delivery statuses..."

CmDeliveryStatus.create( :name => "Under Preparation", :description => "The project is preparing a new delivery", :is_default => 1, :project_id => proj)
CmDeliveryStatus.create( :name => "Delivered", :description => "Delivery performed", :is_closed => 1, :project_id => proj)
CmDeliveryStatus.create( :name => "Received", :description => "Delivery received from externals (subco, customer...)", :is_closed => 1, :project_id => proj)
CmDeliveryStatus.create( :name => "Scheduled", :description => "Delivery scheduled (from project or from externals)", :project_id => proj)

puts "- Creating change statuses..."

CmChangeStatus.create( :name => "New", :description => "Change received from others, or created in the project, but it has not been evaluated yet", :is_default => 1, :project_id => proj)
CmChangeStatus.create( :name => "Accepted", :description => "Change accepted by the project. Work related is in progress", :project_id => proj)
CmChangeStatus.create( :name => "Rejected", :description => "Change has been evaluated by who has received it, but it has been rejected", :project_id => proj)
CmChangeStatus.create( :name => "Approved", :description => "Change finally approved by the project", :is_closed => 1, :project_id => proj)
CmChangeStatus.create( :name => "Delivered", :description => "Change delivered from the project", :project_id => proj)
CmChangeStatus.create( :name => "Withdrawn", :description => "Change has been rejected by its generator and no more versions will be generated", :project_id => proj)

puts "- Creating change types..."

CmChangeType.create( :name => "CR", :acronym => "CR", :description => "Change Request", :is_default => 1 , :project_id => proj)
CmChangeType.create( :name => "CP", :acronym => "CP", :description => "Change Proposal", :project_id => proj)
CmChangeType.create( :name => "CCN", :acronym => "CCN", :description => "Change Contract Notice", :project_id => proj)
CmChangeType.create( :name => "DCN", :acronym => "DCN", :description => "Document Change Notice", :project_id => proj)
CmChangeType.create( :name => "IRN", :acronym => "IRN", :description => "Interface Revision Notice", :project_id => proj)
CmChangeType.create( :name => "ECP", :acronym => "ECP", :description => "Engineering Change Proposal", :project_id => proj)
CmChangeType.create( :name => "RFD", :acronym => "RFD", :description => "Request For Deviation", :project_id => proj)
CmChangeType.create( :name => "RFW", :acronym => "RFW", :description => "Request For Waiver", :project_id => proj)

puts "- Creating risk statuses..."

CmRiskStatus.create( :name => "Identified", :description => "Risk associated to the project has been identified and accepted", :is_default => 1, :project_id => proj)
CmRiskStatus.create( :name => "Mitigated", :description => "The proposed action will try to reduce the exposure to the risk by minimizing the severity of the risk impact, the probability of the risk occurrence or both of them", :project_id => proj)
CmRiskStatus.create( :name => "Avoided", :description => "The proposed action will try to avoid any involvement in the risk situation.", :is_closed => 1, :project_id => proj)
CmRiskStatus.create( :name => "Deferred", :description => "The proposed action(s) will try to raise the time horizon, increasing the days to impact time frame", :project_id => proj)
CmRiskStatus.create( :name => "Transferred", :description => "The risk is transferred or delegated to another person more qualified to reduce the risk exposure with success", :project_id => proj)

puts "- Creating risk types..."

CmRiskType.create( :name => "Financial", :description => "Potential problems with the financiation of the project", :project_id => proj)
CmRiskType.create( :name => "Management", :description => "Potential problems with the management of the project", :project_id => proj)
CmRiskType.create( :name => "Planning Control", :description => "Potential problems with the schedule of the project", :is_default => 1 ,:project_id => proj)
CmRiskType.create( :name => "Cost Control", :description => "Potential problems with the cost of the project", :project_id => proj)
CmRiskType.create( :name => "Subco/Supplier", :description => "Potential problems with subcontractor(s) and/or supplier(s)", :project_id => proj)
CmRiskType.create( :name => "Safety/Dependability", :description => "Potential problems with the safety and/or the dependabilities of the sw", :project_id => proj)
CmRiskType.create( :name => "COTS", :description => "Potencial problems with COTS, version, availability, etc.", :project_id => proj)
CmRiskType.create( :name => "Contract", :description => "Potencial problems with contract", :project_id => proj)

puts "- Creating rid close-outs..."

CmRidCloseOut.create( :name => "Closed with According to Disposition", :description => "Closed with According to Disposition", :project_id => proj, :is_closed => 1)
CmRidCloseOut.create( :name => "Closed with According to AuthorResponse", :description => "Closed with According to AuthorResponse", :project_id => proj, :is_closed => 1)
CmRidCloseOut.create( :name => "Open", :description => "Rid not closed yet", :project_id => proj, :is_default => 1)
CmRidCloseOut.create( :name => "Closed with According Recommendation", :description => "Closed with According Recommendation", :project_id => proj, :is_closed => 1)
CmRidCloseOut.create( :name => "Closed with According to Discrepancy", :description => "Closed with According to Discrepancy", :project_id => proj, :is_closed => 1)
CmRidCloseOut.create( :name => "Closed by Discussion", :description => "Closed by Discussion: no actions are required", :project_id => proj, :is_closed => 1)

puts "- Creating QR types..."

CmQrType.create( :name => "QAP", :description => "Quality Audit Plan")
CmQrType.create( :name => "ADR", :description => "Audit Deviation Report")
CmQrType.create( :name => "QAR", :description => "Quality Audit Report")
CmQrType.create( :name => "QOR", :description => "Quality Objectives Report")
CmQrType.create( :name => "CPA", :description => "Corporate Corrective/Preventive Action")
CmQrType.create( :name => "MRM", :description => "Management Review Minutes of Meeting")
CmQrType.create( :name => "PER", :description => "Supplier Performance Report")
CmQrType.create( :name => "DER", :description => "Design Review Report")
CmQrType.create( :name => "TER", :description => "Test Execution Report")
CmQrType.create( :name => "CIR", :description => "Code Inspection Report")

puts "- Creating TE types..."

CmReqsType.create( :name => "User Req", :acronym => "UR", :description => "Requirements coming from the user", :level => 1, :soc_control => 1, :project_id => proj)
CmReqsType.create( :name => "System Req", :acronym => "SR", :description => "Requirements of the system, traced from the user reqs", :level => 2, :is_default => 1, :project_id => proj)
CmReqsType.create( :name => "Design Module", :acronym => "DM", :description => "Modules to implement the System Requirements", :level => 3, :project_id => proj)

puts "- Creating TE classifications..."

CmReqsClassification.create( :name => "Functional", :description => "Functional Requirements", :is_default => 1, :project_id => proj )
CmReqsClassification.create( :name => "Performance", :description => "Requirements related to Performance issues", :project_id => proj )
CmReqsClassification.create( :name => "User Interface", :description => "Requirements related to the User Interface", :project_id => proj )
CmReqsClassification.create( :name => "Interface", :description => "Requirements related to Interface issues", :project_id => proj )
CmReqsClassification.create( :name => "Operatibility", :description => "Requirements related to Operability", :project_id => proj )
CmReqsClassification.create( :name => "Security", :description => "Requirements related to Security", :project_id => proj )
CmReqsClassification.create( :name => "Safety", :description => "Requirements related to Safety", :project_id => proj )
CmReqsClassification.create( :name => "Constraint", :description => "Requirements related to some existing constraint", :project_id => proj )
CmReqsClassification.create( :name => "Design", :description => "Requirements related to architecture decitions", :project_id => proj )
CmReqsClassification.create( :name => "Product Assurance", :description => "Product Assurance requirements", :project_id => proj )
CmReqsClassification.create( :name => "RAMS", :description => "Requirements related to Realibility, Availability, Maintainability and Safety", :project_id => proj )
CmReqsClassification.create( :name => "Configuration Management", :description => "Configuration Management requirements", :project_id => proj )
CmReqsClassification.create( :name => "Management", :description => "Management requirements", :project_id => proj )
CmReqsClassification.create( :name => "Non Functional", :description => "Non Functional requirements", :project_id => proj )
CmReqsClassification.create( :name => "Physical Deployment", :description => "Requirements related to the Physical Deployment", :project_id => proj )

puts "- Creating test types..."

CmTestType.create( :name => "Test Case", :acronym => "TC", :description => "Test Case. First level of tests definition", :level => 1, :is_default => 1, :test_case => 1, :project_id => proj)
CmTestType.create( :name => "Test Procedure", :acronym => "TP", :description => "Test Procedure - Refine of a Test Case", :level => 2, :test_procedure => 1, :project_id => proj)
CmTestType.create( :name => "Test Step", :acronym => "TS", :description => "Test Step - Refine of a Test Procedure", :level => 3, :test_procedure => 1, :project_id => proj)

puts "- Creating test classifications..."

CmTestClassification.create( :name => "Functionality", :description => "Tests performed to demonstrate some functionality", :is_default => 1, :project_id => proj )
CmTestClassification.create( :name => "Robustness", :description => "Test performed to demonstrate the robutness of the system", :project_id => proj )
CmTestClassification.create( :name => "Performance", :description => "Test performed to see the performance of the system", :project_id => proj )

puts "- Creating test verification methods..."

CmTestVerificationMethod.create(:name => "Analysis",
      :description => "Performing theoretical or empirical evaluation using techniques \
agreed with the Customer (statistics, qualitative design analysis, modelling and computer simulations)")
CmTestVerificationMethod.create(:name => "Inspection",
      :description => "Visual determination of physical characteristics (constructional \
features, conformance to docs, physical conditions, sw source code coding standards)")
CmTestVerificationMethod.create(:name => "Review of Design",
      :description => "Use approved records or evidences that unambiguously show that the requirement is met\
(design docs, design reports, technical descriptions, engineering drawings)")
CmTestVerificationMethod.create(:name => "Test",
      :description => "Measurement of product performance and functions under representative \
simulated environments", :is_default=> 1)

puts "Process ended successfully!"

Process.exit(0)
