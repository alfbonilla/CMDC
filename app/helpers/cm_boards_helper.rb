module CmBoardsHelper
  include ApplicationHelper
  include IssuesHelper
  include CmCommonHelper
  include Redmine::Export::PDF

  def cm_board_to_pdf(cm_board)
    # CMDCFPDF redefines the initialize and SetFontStyle methods in order to
    # allow the use of different font than Arial!
    pdf = CMDCFPDF.new(current_language, "N")
    pdf.SetTitle("Minutes of Meeting")
    pdf.AliasNbPages
    pdf.footer_date = "(c)NESSA Global Banking Solutions"
    pdf.AddPage
    pdf.SetTextColor(0,0,153)

    pdf.Image("#{RAILS_ROOT}/vendor/plugins/redmine_cm/assets/images/company_logo.png",
      pdf.GetX + 5, pdf.GetY + 1, 35, 20, 'png')

    pdf.Cell(50,5, " ", "LT")
    pdf.Cell(80,5, " ", "LT")
    pdf.SetFontStyle('',8)
    pdf.Cell(10,5, "Code: ", "LT")
    pdf.Cell(50,5, cm_board.cm_board_code, "TR")
    pdf.Ln

    pdf.Cell(50,10, " ", "L")
    pdf.SetFontStyle('B',15)
    pdf.Cell(80,10, "Minutes of Meeting", "L", 0, "C")
    pdf.SetFontStyle('',8)
    pdf.Cell(10,10, "Date:", "LT")
    pdf.Cell(50,10, Date.today.strftime("%Y-%m-%d"), "TR")
    pdf.Ln

    pdf.Cell(50,5, " ", "LB")
    pdf.Cell(80,5, " ", "LB")
    pdf.Cell(10,5, "Page: ", "LTB")
    pdf.Cell(50,5, pdf.PageNo.to_s + "/{nb}", "TBR")
    pdf.Ln
    
    pdf.SetFontStyle('B',10)
    pdf.SetFillColor(230, 230, 230)
    pdf.Cell(35,5, "Project:", "LT", 0, "C", 1)

    # Get first line of the project description
    desc_lines=cm_board.project.description.split("\r\n")

    pdf.Cell(155, 5, desc_lines[0][0..85],"LTR")
    pdf.Ln

    pdf.Cell(35,5, "Subject:", "LT", 0, "C", 1)
    if cm_board.subject.length > 75
      pdf.Cell(155, 5, cm_board.subject[0..75],"LTR")
      pdf.Ln
      pdf.Cell(35,5, "", "L", 0, "C", 1)
      pdf.Cell(155, 5, cm_board.subject[76..150],"LR")
    else
      pdf.Cell(155, 5, cm_board.subject,"LTR")
    end
    pdf.Ln

    att_list = ""
    if @cm_board.attachments.any?
      @cm_board.attachments.each do |att|
        att_list = att_list + att.filename + "; "
      end
    end
    if att_list.length > 80
      pdf.Cell(35,5, "Attachments:", "LT", 0, "C", 1)
      pdf.Cell(155, 5, att_list[0..80],"LTR")
      pdf.Ln
      pdf.SetFontStyle('',8)
      pdf.Cell(35,5, " ", "L", 0, "C", 1)
      pdf.Cell(155, 5, att_list[81..160],"LR")
    else
      pdf.Cell(35,5, "Attachments:", "LT", 0, "C", 1)
      pdf.SetFontStyle('',8)
      pdf.Cell(155, 5, att_list,"LTR")
    end
    pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.Cell(35,5, "Venue and date:", "LT", 0, "C", 1)
    pdf.SetFontStyle('',8)
    pdf.Cell(155, 5, @cm_board.company.name + " (" + @cm_board.meeting_date.strftime("%Y-%m-%d") + ")", "LTR")
    pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.Cell(80,5, "Attendee","LT", 0, "C", 1)
    pdf.Cell(40,5, "Company","LT", 0, "C", 1)
    pdf.Cell(70,5, "Signature","LTR", 0, "C", 1)
    pdf.Ln

    pdf.SetFontStyle('',8)

    minutes_taker=""
    attendees=cm_board.participants.split(",")
    attendees.each do |att|
      if att.include? "-"
        parts=att.split("-")
        pdf.Cell(80,15, parts[0],"LT")
        pdf.Cell(40,15, parts[1],"LT")
        #If there is a 2nd dash, is for showing who is the Minutes Taken
        minutes_taker=parts[0] unless parts[2].nil?
      else
        pdf.Cell(80,15, att,"LT")
        pdf.Cell(40,15, " ","LT")
      end

      pdf.Cell(70,15, " ","LTR")
      pdf.Ln
    end

    pdf.SetFontStyle('B',10)
    unless minutes_taker.nil?
      pdf.Cell(35,5, "Minutes Taken by:", "LT", 0, "C", 1)
      pdf.SetFontStyle('',8)
      pdf.Cell(155, 5, minutes_taker,"LTR")
      pdf.Ln
    end

    pdf.SetFontStyle('B',10)
    pdf.Cell(190,5, "Distribution List:", "LTR", 0, "C", 1)
    pdf.Ln
    pdf.SetFontStyle('',8)
    pdf.MultiCell(190, 5, cm_board.distribution_list, "LTBR")

    pdf.SetFontStyle('B',10)
    pdf.Cell(190,5, "Meeting Body:", "LTR", 0, "C", 1)
    pdf.Ln
    pdf.SetFontStyle('',8)
    pdf.MultiCell(190, 5, cm_board.board_body, "LTBR")

    pdf.SetFontStyle('B',10)
    pdf.Cell(190,5, "Conclusions:", "LTR", 0, "C", 1)
    pdf.Ln
    pdf.SetFontStyle('',8)
    pdf.MultiCell(190, 5, cm_board.conclusions, "LTBR")

    row_h=3
    col1_w=20; col2_w=70; col3_w=100
    col2_max=48; col3_max=70
    if @cm_board.cm_objects_issues.any? or @cm_board.cm_changes_objects.any? or
       @cm_board.cm_ncs_objects.any? or @cm_board.cm_rids_objects.any?
      pdf.SetFontStyle('B',8)
      pdf.Cell(col1_w,row_h, "Type","LTB", 0, "C", 1)
      pdf.Cell(col2_w,row_h, "Code","LTB", 0, "C", 1)
      pdf.Cell(col3_w,row_h, "Decision","LTRB", 0, "C", 1)
      pdf.Ln
    end

    # Relationships
    
    pdf.SetFontStyle('',6.5,'FreeSans')
    if  @cm_board.cm_changes_objects.any?
      @cm_board.cm_changes_objects.each do |chn|
        pdf.Cell(col1_w,row_h, "CHANGE","L")
        if chn.cm_change.code.length > col2_max
          pdf.Cell(col2_w,row_h, chn.cm_change.code[0..col2_max],"L")
          pdf.Cell(col3_w,row_h, change_decision_to_s(chn.rel_string.to_i),"LR")
          pdf.Ln
          pdf.Cell(col1_w,row_h, "","L")
          pdf.Cell(col2_w,row_h, chn.cm_change.code[col2_max+1..col2_max*2],"LB")
          pdf.Cell(col3_w,row_h, "","LRB")
        else
          pdf.Cell(col2_w,row_h, chn.cm_change.code,"LB")
          pdf.Cell(col3_w,row_h, change_decision_to_s(chn.rel_string.to_i),"LRB")
        end
        pdf.Ln
      end

      pdf.Cell(col1_w,row_h, " ","LTB", 0, "R", 1)
      pdf.Cell(col2_w,row_h, " ","TB", 0, "R", 1)
      pdf.Cell(col3_w,row_h, "Changes Treated: " + @cm_board.cm_changes_objects.size.to_s,"TBR", 0, "R", 1)
      pdf.Ln
    end

    if  @cm_board.cm_ncs_objects.any?
      @cm_board.cm_ncs_objects.each do |nc|
        pdf.Cell(col1_w,row_h, "NC","L")
        if nc.cm_nc.code.length > col2_max
          pdf.Cell(col2_w,row_h, nc.cm_nc.code[0..col2_max],"L")
          pdf.Cell(col3_w,row_h, change_nc_decision_to_s(nc.rel_string.to_i),"LR")
          pdf.Ln
          pdf.Cell(col1_w,row_h, "","L")
          pdf.Cell(col2_w,row_h, nc.cm_nc.code[col2_max+1..col2_max*2],"LB")
          pdf.Cell(col3_w,row_h, "","LRB")
        else
          pdf.Cell(col2_w,row_h, nc.cm_nc.code,"LB")
          pdf.Cell(col3_w,row_h, change_nc_decision_to_s(nc.rel_string.to_i),"LRB")
        end
        pdf.Ln
      end

      pdf.Cell(col1_w,row_h, " ","LTB", 0, "R", 1)
      pdf.Cell(col2_w,row_h, " ","TB", 0, "R", 1)
      pdf.Cell(col3_w,row_h, "Non-Conformances Treated: " + @cm_board.cm_ncs_objects.size.to_s,"TBR", 0, "R", 1)
      pdf.Ln
    end

    if  @cm_board.cm_rids_objects.any?
      @cm_board.cm_rids_objects.each do |rid|
        pdf.Cell(col1_w,row_h, "RID","L")

        if rid.cm_rid.close_out.name.include?("Author")
          rid_txt="AutRnse: " + rid.cm_rid.author_response
        else
          if rid.cm_rid.close_out.name.include?("Recommendation")
            rid_txt="Recomtn: " + rid.cm_rid.recommendation
          else
            if rid.cm_rid.close_out.name.include?("Disposition")
              rid_txt="Dispstn: " + rid.cm_rid.disposition
            else
              rid_txt=rid.rel_string
            end
          end
        end

        if rid.cm_rid.code.length > col2_max or rid_txt.length > col3_max
          if rid.cm_rid.code.length > col2_max
            pdf.Cell(col2_w,row_h, rid.cm_rid.code[0..col2_max],"L")
          else
            pdf.Cell(col2_w,row_h, rid.cm_rid.code,"L")
          end
          if rid_txt.length > col3_max
            pdf.Cell(col3_w,row_h, rid_txt[0..col3_max],"LR")
          else
            pdf.Cell(col3_w,row_h, rid_txt,"LR")
          end
          pdf.Ln
          pdf.Cell(col1_w,row_h, "","L")
          if rid.cm_rid.code.length > col2_max
            pdf.Cell(col2_w,row_h, rid.cm_rid.code[col2_max+1..col2_max*2],"LB")
          else
             pdf.Cell(col2_w,row_h, "","LB")
          end
          if rid_txt.length > col3_max
             pdf.Cell(col3_w,row_h, rid_txt[col3_max+1..col3_max*2] + "..","LRB")
          else
              pdf.Cell(col3_w,row_h, "","LRB")
          end
        else
          pdf.Cell(col2_w,row_h, rid.cm_rid.code,"LB")
          pdf.Cell(col3_w,row_h, rid_txt,"LRB")
        end
        pdf.Ln
      end
      
      pdf.Cell(col1_w,row_h, " ","LTB", 0, "R", 1)
      pdf.Cell(col2_w,row_h, " ","TB", 0, "R", 1)
      pdf.Cell(col3_w,row_h, "RIDs Treated: " + @cm_board.cm_rids_objects.size.to_s,"TBR", 0, "R", 1)
      pdf.Ln
    end

    if @cm_board.cm_objects_issues.any?
      @cm_board.cm_objects_issues.each do |iss|
        pdf.Cell(col1_w,row_h, "ACTION","L")
        if iss.issue.nil?
          pdf.Cell(col2_w,row_h, "<deleted issue>","LB")
          pdf.Cell(col3_w,row_h, "<deleted issue>","LRB")
        else
          if iss.issue.subject.length > col2_max
            pdf.Cell(col2_w,row_h, iss.issue.subject[0..col2_max],"L")
            pdf.Cell(col3_w,row_h, iss.issue.status.name,"LR")
            pdf.Ln
            pdf.Cell(col1_w,row_h, "","L")
            pdf.Cell(col2_w,row_h, iss.issue.subject[col2_max+1..col2_max*2],"LB")
            pdf.Cell(col3_w,row_h, "","LRB")
          else
            pdf.Cell(col2_w,row_h, iss.issue.subject,"LB")
            pdf.Cell(col3_w,row_h, iss.issue.status.name,"LRB")
          end
        end
        pdf.Ln
      end

      pdf.Cell(col1_w,row_h, " ","LTB", 0, "R", 1)
      pdf.Cell(col2_w,row_h, " ","TB", 0, "R", 1)
      pdf.Cell(col3_w,row_h, "Actions Raised: " + @cm_board.cm_objects_issues.size.to_s,"TBR", 0, "R", 1)
      pdf.Ln
    end

    pdf.Output
  end
end
