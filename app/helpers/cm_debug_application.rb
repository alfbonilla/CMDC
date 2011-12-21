#!/usr/bin/env ruby
#
# Used for reproducing errors with debug
#
# cm_debug_application
#
#
# RAILS_ENV=production ruby script/runner vendor/plugins/redmine_cm/app/helpers/cm_debug_application.rb
#           project_identifier redmine 3306 vendor/plugins/redmine_cm/app/models/ redmine_user redmine
#
#require "mysql"

#Treat input parms
if ARGV.length != 6
  puts "Wrong Number of args:" + ARGV.length.to_s
  puts "Command help:"
  puts "cm_debug_application PROJECT_IDENTIFIER DATABASE_NAME DB_PORT MODEL_PLUGIN_PATH USER PSSWD"
  Process.exit(99)
end

proj=ARGV[0]
db=ARGV[1]
db_port=ARGV[2]
model_path=ARGV[3]
usr=ARGV[4]
psswd=ARGV[5]

puts("Model Path:" + model_path)

require model_path + "cm_req.rb"
require model_path + "cm_reqs_type.rb"
require model_path + "cm_reqs_classification.rb"
require "app/models/project.rb"

con = Mysql.new('localhost', usr, psswd, db, db_port.to_i)

@project = Project.find(:first, :conditions => ['identifier = ?', proj])
if @project==nil
  puts "Error, project " + proj.to_s + " not found!"
  Process.exit(97)
end

puts "Debugging"
puts ">> Database(localhost): " + db
puts ">> Database Port      : " + db_port
puts ">> Model Used         : " + model_path
puts ">> Project            : " + @project.id.to_s
puts ">>>> (project name)   : " + @project.name
puts "Continue (Yes/No)?"
continue_answer=STDIN.gets.chomp

if continue_answer != "Yes"
  puts "Process cancelled by user"
  Process.exit(98)
end

# BEGIN PROCESS TO TEST

  #Values for DEIMOS2 UR > SR
  @te_1=CmReqsType.find(4)
  @te_2=CmReqsType.find(5)

  @conta_ok=0; @conta_errors=0; @conta_warnings=0; @cover_percentage=0
  @matrix_table = []
  table_it = []

  puts("Searching with te1:" + @te_1.id.to_s + " and project:" + @project.id.to_s)

  @reqs_te_1 = CmReq.find(:all, :conditions => ['type_id=? and project_id=?', @te_1.id, @project.id],
      :order => "code ASC")

  @reqs_te_1.each do |te1|
    descendents=""
    puts("(1)Treating Req " + te1.code)
    if @te_1.level < @te_2.level
      te1.cm_reqs_reqs.each do |te2|
        #"Brothers" are not considered
        puts("[Req-Related]" + te2.child_req_id.to_s)
        if te2.relation_type != 3
          puts("[Req-Related-CODE]" + te2.child_req.code)
          descendents=descendents + " " + te2.child_req.code
        end
      end
    else
      reqs_parent = CmReqsReq.find(:all,
        :conditions => ['child_req_id=?', te1.id])

      reqs_parent.each do |te2|
        #"Brothers" are not considered
        if te2.relation_type != 3
          descendents=descendents + " " + te2.parent_req.code
        end
      end
    end
    if descendents.empty?
      if @te_1.level > @te_2.level
        if te1.no_ascendants
          descendents="WARNING"
          @conta_warnings+=1
        else
          descendents="ERROR"
          @conta_errors+=1
        end
      else
        if te1.no_descendants
          descendents="WARNING"
          @conta_warnings+=1
        else
          descendents="ERROR"
          @conta_errors+=1
        end
      end
    else
      @conta_ok+=1
    end
    table_it = [te1.code, descendents, te1.id]

    @matrix_table << table_it
  end

  tot=@conta_ok + @conta_errors + @conta_warnings
  covered=@conta_ok + @conta_warnings

  puts("OK")


# END

con.close

puts "Process ended successfully!"

Process.exit(0)
