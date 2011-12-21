module CmChangesObjectsHelper
  
  def change_decision_to_s(decision)
    case decision
    when 1
      'Raise New'
    when 2
      'Accept'
    when 3
      'Reject'
    when 4
      'Approve'
    when 5
      'Discuss'
    when 6
      'Other'
    end
  end

end