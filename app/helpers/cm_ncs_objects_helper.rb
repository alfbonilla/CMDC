module CmNcsObjectsHelper
  
  def change_nc_decision_to_s(decision)
    case decision
    when 1
      'Rework/Repair'
    when 2
      'Close'
    when 3
      'Reject'
    when 4
      'Use as is'
    when 5
      'Raise RFW/RFD'
    when 6
      'Raise ECR'
    when 7
      'Other'
    end
  end

end