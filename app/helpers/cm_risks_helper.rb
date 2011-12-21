module CmRisksHelper
 
  def change_impact_to_s(impact)
    case impact
    when -1
      'Closed'
    when 1
      'Very Low'
    when 2
      'Low'
    when 3
      'Moderate'
    when 4
      'High'
    when 5
      'Very High'
    when 99
      'Out to Date'
    end
  end

  def calculate_priority (impact_ini_date, impact_end_date, risk_exposure)
    this_day=Date.today

    if this_day > impact_end_date
      return 99
    end

    if this_day < impact_ini_date
      days_to_impact=impact_ini_date - this_day
    else
      days_to_impact=0
    end

    case days_to_impact
    when 0..7
      case risk_exposure
      when 1,2
        return 3
      when 3
        return 4
      else
        return 5
      end
    when 8..30
      case risk_exposure
      when 1
        return 2
      when 2,3
        return 3
      when 4
        return 4
      else
        return 5
      end
    when 31..90
      case risk_exposure
      when 1
        return 1
      when 2
        return 2
      when 3,4
        return 3
      else
        return 4
      end
    when 91..180
      case risk_exposure
      when 1, 2
        return 1
      when 2
        return 2
      else
        return 3
      end
    else
      case risk_exposure
      when 1..3
        return 1
      when 4
        return 2
      else
        return 3
      end
    end

  end

  def calculate_exposure(impact, probability)
    case impact
    when 1
      case probability
      when 0..60
        return 1
      when 61..80
        return 2
      else
        return 3
      end
    when 2
      case probability
      when 0..40
        return 1
      when 41..60
        return 2
      else
        return 3
      end
    when 3
      case probability
      when 0..20
        return 1
      when 21..40
        return 2
      when 41..80
        return 3
      else
        return 4
      end
    when 4
      case probability
      when 0..20
        return 2
      when 21..60
        return 3
      when 61..80
        return 4
      else
        return 5
      end
    when 5
      case probability
      when 0..40
        return 3
      when 41..60
        return 4
      else
        return 5
      end
    end
  end

end