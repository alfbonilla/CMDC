module CmRidsHelper
 def change_internal_status_to_s(internal_status)
    case internal_status
    when 1
      'Open'
    when 2 #Considered Closed
      'Closed'
    when 3 #Considered Closed
      'Withdrawn'
    when 4
      'Responded'
    end
  end

  def change_internal_status_to_i(internal_status)
    case internal_status
    when 'Open'
      1
    when 'Closed'
      2
    when 'Withdrawn'
      3
    when 'Responded'
      4
    end
  end

  def change_external_status_to_s(external_status)
    case external_status
    when 1
      'Open'
    when 2
      'Implemented'
    when 3
      'Closed'
    end
  end

  def change_category_to_s(category)
    case category
    when 1
      'Minor'
    when 2
      'Major'
    when 3
      'Question'
    when 4
      'Comment'
    end
  end

  def change_category_to_i(category)
    # This same code is included in the Import Assistant
    # Consider it in case of modification
    case category
    when 'Minor'
      1
    when 'Major'
      2
    when 'Question'
      3
    when 'Comment'
      4
    else
      99
    end
  end
end