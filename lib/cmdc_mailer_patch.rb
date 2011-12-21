require_dependency 'mailer'

# Patches Redmine's Mailer adding a new method
module CmdcMailerPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
    end

  end

  module ClassMethods

  end

  module InstanceMethods
    def cmdc_info(user, project, cmdc_object, caller_cont)
      # cm_docs has an special treatment. Really the mail is delivered from the
      # doc version: assigned_to field belongs to version.
      # This makes necessary some controls, because:
      # * watchers are the doc ones (version hasn't that possibility)
      # * code, name, etc are attributes from doc
      set_language_if_valid(user.language)

      recipients cmdc_object.recipients
      # Watchers in cc
      if caller_cont == "cm_docs_versions"
        cc(cmdc_object.cm_doc.watcher_recipients - @recipients)
      else
        cc(cmdc_object.watcher_recipients - @recipients)
      end

      # Remove from recipients the author if selected in CMDC Notifications
      # custom field. This query expects to find JUST one entry in tables with
      # CMDC>... New values will require to review this query
      #
      # COMMENTED CODE DUE TO BUG #1778
      #
      #
#      @cmdc_notif=ActiveRecord::Base.connection.select_one("SELECT c.value \
#         FROM #{CustomValue.table_name} c WHERE c.customized_id = #{cmdc_object.author.id} \
#         AND c.customized_type = 'Principal' AND c.value like 'CMDC>%'")
#
#      if @cmdc_notif["value"]=="CMDC>Just as assignee"
#        recipients.delete(cmdc_object.author.mail) if recipients
#        cc.delete(cmdc_object.author.mail) if cc
#      end

      @cmdc_object=cmdc_object
      @project=project
      @caller_cont=caller_cont

      case caller_cont
      when "cm_boards"
        subject '[' + @project.name + ' - ' + @cmdc_object.cm_board_code + '] CM/DC info'
      when "cm_docs_versions"
        subject '[' + @project.name + ' - ' + @cmdc_object.cm_doc.code + '] CM/DC info'
      else
        subject '[' + @project.name + ' - ' + @cmdc_object.code + '] CM/DC info'
      end

      if caller_cont == "cm_docs_versions"
        body :cmdc_object => cmdc_object,
             :cmdc_object_url => url_for(:controller => "cm_docs", :action => :show,
                                        :id => @cmdc_object.cm_doc.id)
      else
        body :cmdc_object => cmdc_object,
             :cmdc_object_url => url_for(:controller => @caller_cont, :action => :show,
                                        :id => @cmdc_object.id)
      end
      render_multipart('cmdc_info', body)
    end
  end
end
