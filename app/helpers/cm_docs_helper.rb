module CmDocsHelper
 def change_baseline_to_s(baseline)
    case baseline
    when 1
      'Functional'
    when 2
      'Development'
    when 3
      'Design'
    when 4
      'Product'
    when 5
      'Test'
    when 6
      'Support'
    else
      'ERROR - Baseline not defined'
    end
  end

  def change_approval_level_to_s(category)
    case category
    when 'A'
      'For Approval'
    when 'R'
      'For Review'
    when 'I'
      'For Information'
    when 'X'
      'For New FOC Document'
    end
  end
end