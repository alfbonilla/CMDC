module CmDocCountersHelper

  # Get next code but called from controllers instead of from forms
  # Used by automatic processes (items hierarchy copy)
  # Get code and update doc_counters table!
  def get_code_from_controller(counter_type, type_name, type_acronym)
    cm_counter_id = counter_type.to_i

    # Prepare vbles for format() method.
    # This method is initially created for items, so unique particle to
    # change is the type_acronym
    @cm_type = type_acronym
    @cm_version = "N/A"
    @cm_subsystem = "N/A"
    @cm_approval_level = "N/A"

    # Get counter
    if cm_counter_id == 0
      # Selected option for searching counter by type name
      @cm_doc_counter = CmDocCounter.find(:first, :conditions => ['name=? and project_id=?',
        type_name, @project.id])
    else
      # Selected option for searching counter by counter id
      @cm_doc_counter = CmDocCounter.find(cm_counter_id)
    end

    @cm_doc_counter.counter = @cm_doc_counter.counter + @cm_doc_counter.increment_by

    # Return generated code
    generated_code=format_name(@cm_doc_counter.format)

    # Update counter
    CmDocCounter.update(@cm_doc_counter.id, :counter => @cm_doc_counter.counter) unless generated_code.nil?

    generated_code
  end

  # Validate the received code in "old_code", giving a new one
  def get_new_code(old_code, pattern, new_value, cm_type="N/A", subsystem="N/A",
     code_version="N/A", cm_approval_level="N/A")

    j=0; i=0
    code_found=false
    new_formatted_name = String.new

    pattern.each_char do |in_char|
      if in_char == '}'
        code_found=false
        next
      end

      if in_char == '{'
        code_found=true
        next
      end

      if code_found
        case in_char
        when '0'..'9'
          # Replace {n} by code
          counter_s = new_value.to_s.rjust(in_char.to_i,'0')
          new_formatted_name.insert j, counter_s
          # Important do not allow to create codes higher than the one expected by code generator
          old_counter = old_code[i, counter_s.length]
          if old_counter.to_i > counter_s.to_i
            raise "Code counter can not be greater than the next expected value by code generator!!"
          end
          j = j + counter_s.length
          i = i + counter_s.length
          code_found=false
        when 'S'
          # Replace by Subsystem (docs, reqs)
          if subsystem == "N/A"
            new_formatted_name = "Error:Subsystem No Defined!"
            break
          else
            new_formatted_name.insert j, subsystem.code
            j = j + subsystem.code.size

            old_subsys=old_code[i, subsystem.code.size]
            if old_subsys != subsystem.code
              raise "Subsystem has been changed! Regenerate Code!"
            end

            i = i + subsystem.code.size
          end
        when 'V'
          if code_version == "N/A"
            new_formatted_name = "Error:Version No Defined!"
            break
          else
            new_formatted_name.insert j, code_version
            j = j + code_version.size

            old_version=old_code[i, code_version.size]
            if old_version != code_version
              raise "Version has been changed! Regenerate Code!"
            end

            i = i + code_version.size
          end
        when 'T'
          # Replace by Type
          if cm_type == "N/A"
            new_formatted_name = "Error:Type not defined!"
            break
          else
            new_formatted_name.insert j, cm_type
            j = j + cm_type.size

            old_subsys=old_code[i, cm_type.size]
            if old_subsys != cm_type
              raise "Type has been changed! Regenerate Code!"
            end

            i = i + cm_type.size
          end
        when 'A'
          if cm_approval_level == "N/A"
            new_formatted_name = "Error:Approval Level not defined!"
            break
          else
            new_formatted_name.insert j, cm_approval_level
            j = j + cm_approval_level.size

            old_version=old_code[i, cm_approval_level.size]
            if old_version != cm_approval_level
              raise "Approval Level has been changed! Regenerate Code!"
            end

            i = i + cm_approval_level.size
          end
        else
          raise "{" + in_char + "} not defined as mask in Code Generator!!"
        end
        next
      end

      if in_char == old_code[i,1]
        new_formatted_name.insert j, old_code[i,1]
        j = j + 1
        i = i + 1
        next
      else
        #Code does not follow the pattern
        raise "Pattern wrong! Char " + old_code[i,1] + " does not match with expected " + in_char
      end
    end

    return new_formatted_name
  end

  def format_name (pattern)
    #Prepare name replacing masks with corresponding values
    #if @cm_doc_counter.format["{C:"]
    #GAL-MAN-DMS-MGF-R_{V:A}_{C:5}.doc
    #Pattern used is the one defined in the type instead of the one defined in the counter

    j= 0
    code_found=false; skip_next=false
    new_formatted_name = String.new

    pattern.each_char do |in_char|
      if skip_next
        skip_next =false
        next
      end

      if in_char == '}'
        code_found=false
        next
      end

      if in_char == '{'
        code_found=true
        next
      else
        if code_found
          case in_char
          when '0'..'9'
            # Replace {n} by code
            counter_s = @cm_doc_counter.counter.to_s.rjust(in_char.to_i,'0')
            new_formatted_name.insert j, counter_s
            j = j + counter_s.length
            skip_next=true
          when 'S'
            # Replace by Subsystem (docs)
            if @cm_subsystem == "N/A"
              if @coming_from_new_doc
                new_formatted_name.insert j, in_char
                j = j + 1
              else
                new_formatted_name = "Error:Subsystem not defined!"
                break
              end
            else
              new_formatted_name.insert j, @cm_subsystem.code
              j = j + @cm_subsystem.code.size
            end
          when 'V'
            if @cm_version == "N/A"
              if @coming_from_new_doc
                new_formatted_name.insert j, in_char
                j = j + 1
              else
                new_formatted_name = "Error:Version not defined!"
                break
              end
            else
              new_formatted_name.insert j, @cm_version
              j = j + @cm_version.size
            end
          when 'T'
            # Replace by Type (docs)
            if @cm_type == "N/A"
              if @coming_from_new_doc
                new_formatted_name.insert j, in_char
                j = j + 1
              else
                new_formatted_name = "Error:Type not defined!"
                break
              end
            else
              new_formatted_name.insert j, @cm_type
              j = j + @cm_type.size
            end
          when 'A'
            if @cm_approval_level == "N/A"
              if @coming_from_new_doc
                new_formatted_name.insert j, in_char
                j = j + 1
              else
                new_formatted_name = "Error:Approval Level not defined!"
                break
              end
            else
              new_formatted_name.insert j, @cm_approval_level
              j = j + @cm_approval_level.size
            end
          else
            new_formatted_name = "Error:Code Mask not defined!"
            break
          end

          code_found=false

        else
          new_formatted_name.insert j, in_char
          j = j + 1
        end
      end
    end

    return new_formatted_name
  end
end