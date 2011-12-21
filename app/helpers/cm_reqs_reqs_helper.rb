module CmReqsReqsHelper
 def change_relation_type_to_s(status)
    case status
    when 1
      'Satisfies'
    when 2
      'Is satisfied by'
    when 3
      'Refers'
    end
  end
end