module CmItemsHelper
  include ApplicationHelper
  include IssuesHelper
  include CmCommonHelper
  include Redmine::Export::PDF

  def cm_item_to_pdf(cm_item, history)
    pdf = CMDCFPDF.new(current_language, "N")
    pdf.SetTitle("#{cm_item.project} - ##{cm_item.code} #{cm_item.id}")
    pdf.AliasNbPages
    pdf.footer_date = format_date(Date.today)
    pdf.AddPage

    pdf.SetFontStyle('B',11)
    pdf.Cell(190,10, "#{cm_item.project} - Item #{cm_item.code} # #{cm_item.id} - #{cm_item.name}")
    pdf.Ln

    y0 = pdf.GetY

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_cm_item_group) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.group.name,"RT")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_status) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.status.name,"RT")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_author) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.author.to_s,"R")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_category) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.category.name,"R")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_type) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.type.name,"R")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_version) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.version,"R")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_created_on) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, format_date(cm_item.created_on),"R")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_item_owner) + ":","L")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.item_owner,"R")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_updated_on) + ":","LB")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, format_date(cm_item.updated_on),"RB")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_configuration_item) + ":","LB")
    pdf.SetFontStyle('',9)
    if cm_item.configuration_item
      pdf.Cell(60,5, "true","RB")
    else
      pdf.Cell(60,5, "false","RB")
    end
    pdf.Ln

    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_item.quantity.to_s,"RB")

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_description) + ":")
    pdf.SetFontStyle('',9)
    pdf.MultiCell(155,5, @cm_item.description,"BR")

    pdf.Line(pdf.GetX, y0, pdf.GetX, pdf.GetY)
    pdf.Line(pdf.GetX, pdf.GetY, 170, pdf.GetY)
    pdf.Ln(10)
  
    if history == 'Y'
      pdf.SetFontStyle('B',9)
      pdf.Cell(190,5, l(:label_history), "B")
      pdf.Ln
      for journal in cm_item.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
        pdf.SetFontStyle('B',8)
        pdf.Cell(190,5, format_time(journal.created_on) + " - " + journal.user.name)
        pdf.Ln
        pdf.SetFontStyle('I',8)
        for detail in journal.details
          pdf.Cell(190,5, "- " + show_detail(detail, true))
          pdf.Ln
        end
        if journal.notes?
          pdf.SetFontStyle('',8)
          pdf.MultiCell(190,5, journal.notes)
        end
        pdf.Ln
      end
    end
    
    if cm_item.attachments.any?
      pdf.SetFontStyle('B',9)
      pdf.Cell(190,5, l(:label_attachment_plural), "B")
      pdf.Ln
      for attachment in cm_item.attachments
        pdf.SetFontStyle('',8)
        pdf.Cell(80,5, attachment.filename)
        pdf.Cell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
        pdf.Cell(25,5, format_date(attachment.created_on),0,0,"R")
        pdf.Cell(65,5, attachment.author.name,0,0,"R")
        pdf.Ln
      end
    end
    pdf.Output
  end

end