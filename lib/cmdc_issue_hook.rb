class CmdcIssueHook < Redmine::Hook::ViewListener

  #Show All objects related to an issue
  render_on :view_issues_show_description_bottom,
    :partial => "cm_commons/related_cmdc_info"
end