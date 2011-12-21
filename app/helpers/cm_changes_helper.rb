module CmChangesHelper
 def change_classification_to_s(classification)
    case classification
    when 1
      'No Impact'
    when 2
      'Implemented with Cost'
    when 3
      'Implemented without Cost'
    end
  end

  def change_implementation_to_s(implementation)
    case implementation
    when 1
      'Implemented'
    when 2
      'No Implemented'
    when 3
      'Partially Implemented'
    when 4
      'Validated and Verified'
    end
  end
end