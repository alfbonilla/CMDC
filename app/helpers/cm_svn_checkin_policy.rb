# Check in policy
# 1- Comments can not be blank
# 2- Files included in /code/ directory has to refer to some existing issue number in Redmine
# 3- Files included in /docs/ directory are treated as documents, and will be managed through Redmine_Cm plugin
#
# If documents are managed using SVN, a semi-automatic approach can be taken: use SVN properties
# * Assign to every single doc the property called "cm_doc_id" and the integer key assigned when the doc is
#   created in redmine DB as the value
# * This is requested for the very first time, when the doc is created. Next operations over the file will
#   automatically update the auditory data of the doc in the DB

def get_author_id
  commit_author = `#{$svnlook} author #{$repo_path} -t #{$transaction}`.downcase

  redmine_user = `#{$mysql} --database=bitnami_redmine --user=root --password=adminadmin \
           -e "SELECT id FROM users WHERE login = '#{commit_author.strip()}';" --skip-column-names`.strip()

  if redmine_user.empty?
    STDERR.puts "[cmError] User performing the commit (" + commit_author + ") is not a Redmine user!"
    exit(1)
  end

  $author_id = redmine_user.to_i
end

def update_doc (id_to_update, file)

  date_to_set = Time.now.strftime("%Y-%m-%d")

  STDERR.puts "date:" + date_to_set

  STDERR.puts("Document #{file} found, Updating in DB...")
       update_result = `#{$mysql} --database=bitnami_redmine --user=root --password=adminadmin \
       -e "UPDATE cm_docs SET name = '#{file}', author_id = #{$author_id}, updated_on = '#{date_to_set}' WHERE id = #{id_to_update};" \
       select row_count();" --skip-column-names`.strip()

    # INCLUDE SOME JOURNALS!!!!
    # insert into journals, jounalized_id = cm_doc_id, journalized_type = CmDoc, user_id = xxx, created_on = date, notes = change description
    # a good change description avoids to insert a new record in the jorurnal_details table

    STDERR.puts "[cmError] Error updating doc #{id_to_update}!! Commit cancelled" if (update_result.eql?("0"))
end

#MAIN
$repo_path = ARGV[0]
$transaction = ARGV[1]
$svnlook = ARGV[2]  #'svnlook.exe'
$mysql = ARGV[3] #'mysql.exe'
$author_id = 0

$svnlook='"C:\Program Files\BitNami RubyStack\subversion\bin\svnlook.exe"'
$svn='"C:\Program Files\BitNami RubyStack\subversion\bin\svn.exe"'
$mysql='"C:\Program Files\BitNami RubyStack\mysql\bin\mysql.exe"'

# (1) Validation for empty comments
commit_log = `#{$svnlook} log #{$repo_path} -t #{$transaction}`

#tree = `#{$svnlook} tree #{$repo_path} -t #{$transaction} --show-ids`

tree = `#{$svnlook} uuid #{$repo_path} `
STDERR.puts "tree:" + tree

#UNCOMMENT THIS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#if (commit_log == nil || commit_log.length < 2)
#  STDERR.puts("[cmError] Log message cannot be empty. Please include some commit description!")
#  exit(1)
#end

# Get author from redmine!
get_author_id()
commit_changed = `#{$svnlook} changed #{$repo_path} -t #{$transaction} `
STDERR.puts "commit:" + commit_changed.to_s
# FOR TESTING: commit_changed = "U trunk/Delete.doc\nU trunk/Delete11.pdf\n"
files = commit_changed.split(/\n/)
doc_id = nil
for file in files
  # Control for "document files" in documents folder
  # */documents/*
  just_file=file[file.rindex('/')+1..file.length]

  if(file =~ /\/docs\//)
    STDERR.puts ">>>Reviewing Doc " + file.to_s + "..."

    #Just for those cases where the modified item is the own folder
    next if (file =~ /\/docs\/$/)

    file_and_path=file[file.index(' ' )+1..file.length]
    just_file=file[file.rindex('/')+1..file.length]

    #Read property cm_doc_id
    doc_id = `#{$svnlook} -t #{$transaction} propget #{$repo_path} cm_doc_id #{file_and_path}`

    STDERR.puts ">>>cm_doc_id found: " + doc_id.to_s if not doc_id.empty?

    if doc_id.empty?
      #Search for filename. It could be created directly in DB, so no property
      STDERR.puts ">>>Searching for Doc name " + just_file + "..."
      cm_doc_id_from_name = `#{$mysql} --database=bitnami_redmine --user=root --password=adminadmin \
               -e "SELECT id FROM cm_docs WHERE name = '#{just_file}';" --skip-column-names`.strip()
      if cm_doc_id_from_name.empty?
        #Create New doc
        STDERR.puts ">>>Document #{just_file}not found, creating a new entry in DB"

        inserted_id = `#{$mysql} --database=bitnami_redmine --user=root --password=adminadmin \
               -e "INSERT INTO cm_docs (name, type, author_id) VALUES ('#{just_file}', 'Not Assigned', '#{$author_id}'); \
               select last_insert_id();" --skip-column-names`.strip()

        if inserted_id.empty?
          STDERR.puts "[cmErro] Error inserting new doc!! Id not returned from DB. Commit cancelled"
          exit(1)
        end

        new_id = inserted_id
      else
        #Update doc
        update_doc(cm_doc_id_from_name, just_file)

        new_id = cm_doc_id_from_name
      end

      #Set property
      STDERR.puts $svn + " propset cm_doc_id " + new_id + " on " + just_file
      #STDERR.puts $svn + " propset cm_doc_id " + new_id + " on " + file_and_path + " " + $repo_path + "."
      `#{$svn} propset cm_doc_id #{new_id} on #{just_file}`
      #propset PROPNAME --revprop -r REV PROPVAL [TARGET]
    else
      #Update doc
      update_doc(doc_id, just_file)
    end
  else
    # code?
    if(file =~ /\/code\//)
      # (2) Association of ALL the source code commits to some issue number
      if (commit_log =~ /refs|fixes|closes\s#([0-9]+)/)
        #issue_number = $1
        issue_number = commit_log[/#([0-9]+)/][/([0-9]+)/]
        redmine_issue_open = `#{$mysql} --database=bitnami_redmine --user=root --password=adminadmin \
                 -e "SELECT COUNT(*) AS result FROM issues I INNER JOIN issue_statuses S ON S.id = I.status_id \
                 WHERE S.is_closed = 0 AND I.id = #{issue_number};" --skip-column-names`.strip()
        if (redmine_issue_open.eql?("0"))
          STDERR.puts("[cmError] Redmine issue #{issue_number} is not in an open state. Please, select other "+
                      "issue or reopen the desired one")
          exit(1)
        end
      else
        STDERR.puts("[cmError] You didn't specify a Redmine issue number on the first line, e.g.:
          <comment> refs|fixes|closes #<issueNumber> [<more comments>]
          rest of commit message...")
        exit(1)
      end
    else
      # no controlled items
      STDERR.puts "[CmWarning] File included in repo is not a code or document"
    end
  end
end

# CANCEL COMMIT ALWAYS: TESTING!!!!
exit(1)

