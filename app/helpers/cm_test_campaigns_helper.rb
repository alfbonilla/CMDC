module CmTestCampaignsHelper
  
  def change_tk_status_to_s(status)
    case status
    when 1
      'Scheduled'
    when 2
      'In Progress'
    when 3
      'Finished'
    when 4
      'Suspended'
    end
  end

  def change_tk_status_to_i(status)
    case status
    when 'Scheduled'
      1
    when 'In Progress'
      2
    when 'Finished'
      3
    when 'Suspended'
      4
    end
  end
end