require 'redmine'
require 'dispatcher'

Dispatcher.to_prepare do
  require_dependency 'mailer'
  require_dependency 'cmdc_issue_hook'
  require 'cmdc_mailer_patch'

  Mailer.send(:include, CmdcMailerPatch)
end

if RAILS_ENV == 'development'
  ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end

Redmine::Plugin.register :redmine_cm do
  name 'Configuration Management Data Center'
  author 'AFBB & ABMM'
  description 'This plugin covers all the Configuration Management /
      infrastructure required for covering in the easiest possible way all the CM requirements /
      coming from the customer and from the company.'

  # Try to get the SVN installed release
  entries_path = "#{RAILS_ROOT}/vendor/plugins/redmine_cm/.svn/entries"
  if File.readable?(entries_path)
    begin
      f = File.open(entries_path, 'r')
      entries = f.read
      f.close
      if entries.match(%r{^\d+})
        revision = $1.to_i if entries.match(%r{^\d+\s+dir\s+(\d+)\s})
      else
        xml = REXML::Document.new(entries)
        revision = xml.elements['wc-entries'].elements[1].attributes['revision'].to_i
      end
    rescue
    # Could not find the current revision
    end
  end

  unless revision.nil?
    version '1.2.0 r'+revision.to_s
  else
    version '1.2.0'
  end

  settings :default => {
    'non_conformances_or_issues' => '',
  }, :partial => 'settings/cmdc_settings'

  project_module :cm_dc do
       
      #REFERENCE TABLES Edit Permissions (new,edit and delete).
      permission :edit_Reference_Tables, :cm_delivery_statuses => [:new,:edit,:destroy],
        :cm_item_statuses => [:new,:edit,:destroy],:cm_item_classifications => [:new,:edit,:destroy],
        :cm_item_groups => [:new,:edit,:destroy],:cm_item_categories => [:new,:edit,:destroy],:cm_item_types => [:new,:edit,:destroy],
        :cm_mnt_log_statuses => [:new,:edit,:destroy],:cm_mnt_log_types => [:new,:edit,:destroy],
        :cm_reqs_classifications => [:new,:edit,:destroy],:cm_reqs_types => [:new,:edit,:destroy],
        :cm_test_types => [:new,:edit,:destroy],:cm_test_classifications => [:new,:edit,:destroy],
        :cm_change_statuses => [:new,:edit,:destroy],:cm_change_types => [:new,:edit,:destroy],
        :cm_doc_statuses => [:new,:edit,:destroy],:cm_doc_types => [:new,:edit,:destroy],
        :cm_board_types => [:new,:edit,:destroy],
        :cm_risk_statuses => [:new,:edit,:destroy],:cm_risk_types => [:new,:edit,:destroy],
        :cm_rid_close_outs => [:new,:edit,:destroy],
        :cm_ncs_phases => [:new,:edit,:destroy],:cm_ncs_classifications => [:new,:edit,:destroy],
        :cm_ncs_statuses => [:new,:edit,:destroy],:cm_ncs_types => [:new,:edit,:destroy],
        :cm_qr_types => [:new,:edit,:destroy],
        :cm_companies => [:new,:edit,:destroy],
        :cm_subsystems => [:new,:edit,:destroy],
        :cm_source_files => [:new,:edit,:destroy]

      #REFERENCE TABLES View Permissions (index and show).
      permission :view_Reference_Tables, :cm_delivery_statuses => [:index,:show],
        :cm_item_statuses => [:index,:show],:cm_item_classifications => [:index,:show],
        :cm_item_groups => [:index,:show],:cm_item_categories => [:index,:show],:cm_item_types => [:index,:show],
        :cm_mnt_log_statuses => [:index,:show],:cm_mnt_log_types => [:index,:show],
        :cm_reqs_classifications => [:index,:show],:cm_reqs_types => [:index,:show],
        :cm_test_types => [:index,:show],:cm_test_classifications => [:index,:show],
        :cm_change_statuses => [:index,:show],:cm_change_types => [:index,:show],
        :cm_doc_statuses => [:index,:show],:cm_doc_types => [:index,:show],
        :cm_board_types => [:index,:show],
        :cm_risk_statuses => [:index,:show],:cm_risk_types => [:index,:show],
        :cm_rid_close_outs => [:index,:show],
        :cm_ncs_phases => [:index,:show],:cm_ncs_classifications => [:index,:show],
        :cm_ncs_statuses => [:index,:show],:cm_ncs_types => [:index,:show],
        :cm_qr_types => [:index,:show],
        :cm_companies => [:index,:show],
        :cm_subsystems => [:index,:show],
        :cm_source_files => [:index,:show]

      permission :view_cm_commons, :cm_commons => :index, :public => true
      permission :import_cm_objects, :cm_commons => :import_objects

      permission :view_cm_items, :cm_items => [ :index, :show, :index_tree ]
      permission :edit_cm_items, :cm_items => [ :edit, :new, :destroy, :relate_items, :copy_item ]

      permission :view_cm_boards, :cm_boards => [ :show, :index ]
      permission :edit_cm_boards, :cm_boards => [ :new, :edit, :destroy, :reopen ]
      
      permission :view_cm_changes, :cm_changes => [ :show, :index, :index_tree ]
      permission :edit_cm_changes, :cm_changes => [ :new, :edit, :destroy ]
     
      permission :view_cm_deliveries, :cm_deliveries => [ :show, :index ]
      permission :edit_cm_deliveries, :cm_deliveries => [ :new, :edit, :destroy ]
      
      permission :view_cm_docs, :cm_docs => [ :show, :index ]
      permission :edit_cm_docs, :cm_docs => [ :new, :edit, :destroy ]

      permission :view_cm_purchase_orders, :cm_purchase_orders => [ :index, :show ]
      permission :edit_cm_purchase_orders, :cm_purchase_orders => [ :edit, :new, :destroy ]

      permission :view_cm_mnt_logs, :cm_mnt_logs => [ :index, :show ]
      permission :edit_cm_mnt_logs, :cm_mnt_logs => [ :edit, :new, :destroy ]
      
      permission :view_cm_doc_counter, :cm_doc_counters => [ :index ]
      permission :edit_cm_doc_counter, :cm_doc_counters => [ :new, :new_doc, :edit, :destroy ]

      permission :view_cm_ncs, :cm_ncs => [ :show, :index, :summary ]
      permission :edit_cm_ncs, :cm_ncs => [ :new, :edit, :destroy, :new_issue]
 
      permission :view_cm_was, :cm_was => [ :show, :index ]
      permission :edit_cm_was, :cm_was => [ :new, :edit, :destroy ]

      permission :view_cm_qrs, :cm_qrs => [ :show, :index ]
      permission :edit_cm_qrs, :cm_qrs => [  :new, :edit, :destroy ]

      permission :view_cm_rids, :cm_rids => [ :show, :index, :summary ]
      permission :edit_cm_rids, :cm_rids => [ :new, :edit, :destroy ]
      
      permission :view_cm_risks, :cm_risks => [ :show, :index ]
      permission :edit_cm_risks, :cm_risks => [ :new, :edit, :destroy, :refresh_priority ]
      
      permission :view_cm_smrs, :cm_smrs => [ :show, :index ]
      permission :edit_cm_smrs, :cm_smrs => [ :new, :edit, :destroy ]
      permission :edit_cm_smrs_affected_files, :cm_smrs_affected_files => [ :new, :edit, :destroy ]

      permission :view_cm_reqs, :cm_reqs => [ :show, :index, :summary, :index_tree, :matrix ]
      permission :edit_cm_reqs, :cm_reqs => [ :new, :edit, :destroy, :new_issue, :import_trace]
      permission :track_cm_req_changes, :cm_reqs => [:approve, :reject, :dismiss, :propose, :approve_all]

      permission :view_cm_tests, :cm_tests => [:show, :index ]
      permission :edit_cm_tests, :cm_tests => [:new, :edit, :destroy, :copy ]

      permission :view_cm_test_scenarios, :cm_test_scenarios => [ :show, :index ]
      permission :edit_cm_test_scenarios, :cm_test_scenarios => [:new,:edit,:destroy]

      permission :view_cm_test_campaigns, :cm_test_campaigns => [ :show, :index ]
      permission :edit_cm_test_campaigns, :cm_test_campaigns => [:new, :edit, :destroy]

      permission :view_cm_test_records, :cm_test_records => [ :show, :index ]
      permission :edit_cm_test_records, :cm_test_records => [:new, :edit, :destroy]

      permission :view_cmdc_object_watchers, {}
      permission :add_cmdc_object_watchers, {:watchers => :new}
  end

  menu :project_menu, :cm_commons, { :controller => 'cm_commons', :action => 'index' }, :caption => 'CM/DC',
        :after => :activity, :param => :id
end
