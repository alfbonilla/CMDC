#!/usr/bin/env ruby
#
# Load the redmine database plugin tables. Format
#
# cm_load_data_model PROJECT DATABASE PORT MODEL_PLUGIN_PATH USR PSSWD DELETE|KEEP
#
#
# RAILS_ENV=production ruby script/runner vendor/plugins/redmine_cm/app/helpers/cm_load_data_model.rb
#           1 redmine 3306 vendor/plugins/redmine_cm/app/models/ redmine_user redmine DELETE
#
#require "mysql"

#Treat input parms
if ARGV.length != 7
  puts "Wrong Number of args:" + ARGV.length.to_s
  puts "Command help:"
  puts "cm_load_data_model PROJECT DATABASE DB_PORT MODEL_PLUGIN_PATH USER PSSWD DELETE|KEEP"
  puts ">> DELETE: delete all records in RTs with received project"
  puts ">> KEEP: do not delete records in RTs with received project"
  Process.exit(99)
end

proj=ARGV[0]
db=ARGV[1]
db_port=ARGV[2]
model_path=ARGV[3]
usr=ARGV[4]
psswd=ARGV[5]
delete=ARGV[6]

#model_path="C:/Program Files/BitNami RubyStack/apps/redmine/vendor/plugins/redmine_cm/app/models/"

require model_path + "cm_reqs_type.rb"
require model_path + "cm_reqs_classification.rb"
require model_path + "cm_doc_counter.rb"
require "app/models/project.rb"

if delete == "DELETE"
  delete = "Yes"
else
  delete = "No"
end

con = Mysql.new('localhost', usr, psswd, db, db_port.to_i)

project = Project.find(proj.to_i)
if project==nil
  puts "Error, project " + proj.to_s + " not found!"
  Process.exit(97)
end

puts "Load Info"
puts ">> Database(localhost): " + db 
puts ">> Database Port      : " + db_port
puts ">> Model Used         : " + model_path
puts ">> Project to load    : " + proj.to_s
puts ">>>> (project name)   : " + project.name
puts ">> Delete Records     : " + delete
puts "Continue (Yes/No)?"
continue_answer=STDIN.gets.chomp

if continue_answer != "Yes"
  puts "Process cancelled by user"
  Process.exit(98)
end

if delete == "Yes"
  CmReqsType.delete_all(:project_id => proj)
  CmReqsClassification.delete_all(:project_id => proj)
end

CmReqsType.create( :name => "User Req", :description => "Requirements coming from the user", :level => 1, :is_default => 1, :project_id => proj)
CmReqsType.create( :name => "System Req", :description => "Requirements of the system, traced from the user reqs", :level => 2, :project_id => proj)
CmReqsType.create( :name => "Design Module", :description => "Modules to implement the System Requirements", :level => 3, :project_id => proj)

CmReqsClassification.create( :name => "Functional", :description => "Functional Requirements", :is_default => 1, :project_id => proj )
CmReqsClassification.create( :name => "Performance", :description => "Requirements related to Performance issues", :project_id => proj )
CmReqsClassification.create( :name => "User Interface", :description => "Requirements related to the User Interface", :project_id => proj )
CmReqsClassification.create( :name => "Interface", :description => "Requirements related to Interface issues", :project_id => proj )
CmReqsClassification.create( :name => "Operatibility", :description => "Requirements related to Operability", :project_id => proj )
CmReqsClassification.create( :name => "Security", :description => "Requirements related to Security", :project_id => proj )
CmReqsClassification.create( :name => "Safety", :description => "Requirements related to Safety", :project_id => proj )
CmReqsClassification.create( :name => "Constraint", :description => "Requirements related to some existing constraint", :project_id => proj )

CmDocCounter.create( :name => "User Req", :format => "PROJ_REQ-U_{5}", :counter => 0, :project_id => proj)
CmDocCounter.create( :name => "System Req", :format => "PROJ_REQ-S_{5}", :counter => 0, :project_id => proj)
CmDocCounter.create( :name => "Design Req", :format => "PROJ_REQ-D_{5}", :counter => 0, :project_id => proj)

con.close

puts "Process ended successfully!"

Process.exit(0)

