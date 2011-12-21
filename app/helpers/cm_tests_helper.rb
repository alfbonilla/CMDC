module CmTestsHelper

  def change_result_to_s(result)
    case result
      when 0
        'In Process'
      when 1
        'Failed'
      when 2
        'Passed'
      when 3
        'Passed with Restrictions'
    end
  end

 def change_relation_type_to_s(status)
    case status
    when 1
      'Is part of' #Father test
    when 2
      'Composed by' #Child test
    end
  end
end