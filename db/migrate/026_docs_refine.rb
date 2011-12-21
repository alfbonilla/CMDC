class DocsRefine < ActiveRecord::Migration
  def self.up
    add_column :cm_docs_versions, :physical_location, :string, :default => "", :null => false
    add_column :cm_docs_versions, :status_id, :integer, :null => false
    add_column :cm_docs_versions, :assigned_to_id, :integer, :default => 0

    # Review all docs. If the document has versions already created, and the version is the same
    # than in the doc, the new field physical location is copied.
    # If all versions are different, a new record is created
    docs=CmDoc.find(:all)

    puts "Migration of cm_docs data to cm_docs_versions"
    puts "Docs in db: " + docs.size.to_s

    docs.each do |doc|
      version_found=false

      puts doc.name + " => versions found: " + doc.cm_docs_versions.size.to_s

      doc.cm_docs_versions.each do |ver|

        puts "* ver-version: " + ver.version + "<=> doc_version: " + doc.version

        if ver.version == doc.version

          puts "** Versions match. Updating physical location and status"
          puts "**** physical_location replaced in version table:" + ver.physical_location

          ver.physical_location = doc.physical_location
          ver.status_id = doc.status_id
          ver.assigned_to_id = doc.assigned_to_id
          version_found=true

          unless ver.save
            puts "Error saving!"
          end
        end
      end

      unless version_found
        puts "* Doc without versions: creating new one"

        unless CmDocsVersion.create({:version => doc.version,
            :physical_location => doc.physical_location,
            :cm_doc_id => doc.id, :applicable => doc.applicable,
            :status_id => doc.status_id, :assigned_to_id => doc.assigned_to_id,
            :author => User.current})
            puts "error creating!"
        end
      end
    end

    remove_column :cm_docs, :physical_location
    remove_column :cm_docs, :applicable
    remove_column :cm_docs, :version
    remove_column :cm_docs, :status_id
    remove_column :cm_docs, :assigned_to_id

    rename_column :cm_docs, :applicable_to, :originator_company_id

    add_column :cm_docs, :referable, :boolean, :default => false

    change_column :cm_docs, :description, :text
    change_column :cm_docs, :external_doc_id, :string, :limit => 50, :null => false
  end

  def self.down
    remove_column :cm_docs_versions, :physical_location
    remove_column :cm_docs_versions, :status_id
    remove_column :cm_docs_versions, :assigned_to_id

    # Data... could not be retrieved... :O
    add_column :cm_docs, :version, :string, :limit => 10, :default => "", :null => false
    add_column :cm_docs, :physical_location, :string, :default => "", :null => false
    add_column :cm_docs, :applicable, :boolean, :default => false
    add_column :cm_docs, :status_id, :integer, :null => false
    add_column :cm_docs, :assigned_to_id, :integer, :default => 0

    rename_column :cm_docs, :originator_company_id, :applicable_to

    change_column :cm_docs, :description, :string, :default => "", :null => false
    change_column :cm_docs, :external_doc_id, :string, :limit => 30, :default => "", :null => false
  end
end
