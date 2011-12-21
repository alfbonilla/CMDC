module CmPurchaseOrdersHelper
  include ApplicationHelper
  include IssuesHelper
  include Redmine::Export::PDF

  def cm_po_to_pdf(cm_purchase_order, history)
    pdf = CMDCFPDF.new(current_language, "N")
    pdf.SetTitle("#{cm_purchase_order.project} - ##{cm_purchase_order.code}")
    pdf.AliasNbPages
    pdf.footer_date = Date.today.strftime("%d/%m/%Y")
    pdf.AddPage

    pdf.Image("#{RAILS_ROOT}/vendor/plugins/redmine_cm/assets/images/company_logo.png",
      pdf.GetX + 5, pdf.GetY + 1, 35, 20, 'png')
    pdf.Ln
    
    pdf.SetFontStyle('B',11)
    pdf.Cell(190,10, "#{cm_purchase_order.project} - Item #{cm_purchase_order.code} # #{cm_purchase_order.id} - #{cm_purchase_order.title}")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_title) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(80,5, cm_purchase_order.title,"RT")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_code) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(40,5, cm_purchase_order.code,"RT")
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_requested_by) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_purchase_order.requested_by,"RT")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_requested_date) + ":","LT")
    pdf.SetFontStyle('',9)
    if cm_purchase_order.requested_date.nil?
      pdf.Cell(60,5, "Unknown","RT")
    else
      pdf.Cell(60,5, cm_purchase_order.requested_date.strftime("%d/%m/%Y"),"RT")
    end
    
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_authorized_by) + ":","LT")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, cm_purchase_order.authorized_by,"RT")
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_authorized_date) + ":","LT")
    pdf.SetFontStyle('',9)
    if cm_purchase_order.authorized_date.nil?
      pdf.Cell(60,5, "Unknown","RT")
    else
      pdf.Cell(60,5, cm_purchase_order.authorized_date.strftime("%d/%m/%Y"),"RT")
    end
    pdf.Ln

    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_supplier) + ":", "TBL")
    pdf.SetFontStyle('',9)
    if @cm_purchase_order.supplier.nil?
      pdf.Cell(60,5, "Unknown","TBL")
    else
      pdf.Cell(60,5, @cm_purchase_order.supplier.name,"TBL")
    end
    pdf.SetFontStyle('B',9)
    pdf.Cell(35,5, l(:field_budget) + ":", "TBL")
    pdf.SetFontStyle('',9)
    pdf.Cell(60,5, @cm_purchase_order.budget,"TBRL")
    pdf.Ln(10)

    if @cm_purchase_order.cm_po_details.any?
      pdf.SetFontStyle('B',9)
      pdf.Cell(90,5, l(:field_name) + ":","LTB")
      pdf.SetFontStyle('B',9)
      pdf.Cell(30,5, l(:field_cost) + ":","LTB")
      pdf.SetFontStyle('B',9)
      pdf.Cell(30,5, l(:field_unit) + ":","LTB")
      pdf.SetFontStyle('B',9)
      pdf.Cell(40,5, l(:field_reception_date) + ":","LTBR")
      pdf.Ln

      @cm_purchase_order.cm_po_details.each do |iitem|
        pdf.SetFontStyle('',9)
        pdf.Cell(90,5, iitem.item.name,"LB")
        pdf.SetFontStyle('',9)
        pdf.Cell(30,5, iitem.cost_per_unit.to_s,"LB")
        pdf.SetFontStyle('',9)
        pdf.Cell(30,5, iitem.quantity.to_s,"LB")
        pdf.SetFontStyle('',9)
        if iitem.reception_date.nil?
          pdf.Cell(40,5, "Unknown","LBR")
        else
          pdf.Cell(40,5, iitem.reception_date.strftime("%d/%m/%Y"),"LBR")
        end
        pdf.Ln
      end
    end

    pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.Cell(90,5, "Total","LBT")
    pdf.SetFontStyle('B',10)
    pdf.Cell(30,5, @cm_purchase_order.total_payment.to_s,"LBT")
    pdf.SetFontStyle('B',10)
    pdf.Cell(70,5, "VAT:" + @cm_purchase_order.VAT_included.to_s + " %","LBTR")

    pdf.Ln(10)

    if history == 'Y'
      pdf.SetFontStyle('B',9)
      pdf.Cell(190,5, l(:label_history), "B")
      pdf.Ln
      for journal in cm_purchase_order.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
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
    
    pdf.Output
  end

end