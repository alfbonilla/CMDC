module CmChangesChangesHelper
  
  def change_relation_type_to_s(relation_type)
    case relation_type
    when 1
      'derives from'
    when 2
      'is contained in'
    when 3
      'answers to'
    when 4
      'ammends to'
    when 5
      'references to'
    end
  end

end