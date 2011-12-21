module CmDeliveriesHelper
  include ApplicationHelper
  include IssuesHelper
  include CmCommonHelper
  include Redmine::Export::PDF

  def cm_delivery_to_pdf(cm_delivery)
    pdf = CMDCFPDF.new(current_language, "N")
    pdf.SetTitle("Delivery Release Note")
    pdf.AliasNbPages
    pdf.footer_date = "(c)DEIMOS Space S.L.U."
    pdf.AddPage
    pdf.SetTextColor(0,0,153)

    pdf.Image("#{RAILS_ROOT}/vendor/plugins/redmine_cm/assets/images/company_logo.png",
      pdf.GetX + 5, pdf.GetY + 1, 35, 20, 'png')

    pdf.Cell(50,5, " ", "LT")
    pdf.Cell(80,5, " ", "LT")
    pdf.SetFontStyle('',8)
    pdf.Cell(10,5, "Code: ", "LT")
    pdf.Cell(50,5, cm_delivery.code, "TR")
    pdf.Ln

    pdf.Cell(50,10, " ", "L")
    pdf.SetFontStyle('B',15)
    pdf.Cell(80,10, "Delivery Release Note", "L", 0, "C")
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
    pdf.Cell(95,5, "Project", "LT", 0, "C", 1)
    pdf.Cell(95,5, "Release Data", "LTR", 0, "C", 1)
    pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.Cell(35, 5, "Project Name:","LT")
    pdf.SetFontStyle('',10)
    desc_lines=cm_delivery.project.description.split("\r\n")
    # After the split, desc_lines is an array of strings. We are insterested
    # just in the first line => desc_lines[0]
    pdf.Cell(60, 5, desc_lines[0][0..33],"T")
    pdf.SetFontStyle('B',10)
    pdf.Cell(35, 5, "Release Date:","LT")
    pdf.SetFontStyle('',10)
    if cm_delivery.delivery_date.nil?
      pdf.Cell(60, 5, " ","RT")
    else
      pdf.Cell(60, 5, cm_delivery.delivery_date.strftime("%Y-%m-%d"),"RT")
    end
    pdf.Ln

    write_project_line(pdf, 33, desc_lines[0]) if desc_lines[0].length > 33

    pdf.SetFontStyle('B',10)
    pdf.Cell(35,5, "Project Acronym:","L")
    pdf.SetFontStyle('',10)
    pdf.Cell(60,5, cm_delivery.project.name,"R")
    pdf.SetFontStyle('B',10)
    pdf.Cell(35,5, l(:field_approved_by) + ":")
    pdf.SetFontStyle('',10)
    if cm_delivery.approver.nil?
      pdf.Cell(60,5, " ","R")
    else
      pdf.Cell(60,5, cm_delivery.approver.name,"R")
    end
    pdf.Ln

    signature_file = Attachment.find(:first, :conditions => ['container_id=? and container_type=? and filename=?',
          @project.id, "Project", cm_delivery.approver.login + "_signature.png"])

    pdf.SetFontStyle('B',10)
    pdf.Cell(35,5, "Project Phase:","L")
    pdf.SetFontStyle('',10)
    if @cm_delivery.release.nil?
      pdf.Cell(60,5, " ","R")
    else
      pdf.Cell(60,5, cm_delivery.release.name,"R")
    end
    pdf.SetFontStyle('B',10)
    pdf.Cell(35,5, "Signature:")

    if signature_file.nil?
      pdf.SetFontStyle('',10)
      pdf.Cell(60,5, " ","R")
    else
      pdf.Cell(60,5, " ","R")
      pdf.Image("#{Attachment.storage_path + "/" + signature_file.disk_filename}",
      pdf.GetX - 60, pdf.GetY,50, 23, 'png')
          end
    pdf.Ln

    pdf.Cell(95,20, " ", "L")
    pdf.Cell(95,20, " ", "LR")
    pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.SetFillColor(230, 230, 230)
    pdf.Cell(190,10, "Changes implemented in this release:", "LTR", 0, "L", 1)
    pdf.Ln

    pdf.SetFontStyle('',10)
    pdf.MultiCell(190,5, cm_delivery.description, "LTR")
    #pdf.Ln

    pdf.SetFontStyle('B',10)
    pdf.Cell(190,10, "Configuration Items included in this release:", "LTR", 0, "L", 1)
    pdf.Ln

    @row_h=4
    @col1_w=15; @col2_w=45; @col3_w=73; @col4_w=12; @col5_w=45;
    # col6 = col4 + col5
    @col6_w=57
    @col_max=45

    header_1_printed=false
    header_2_printed=false

    if @cm_delivered_items.any?
      print_header_1(pdf)
      header_1_printed=true

      @cm_delivered_items.each do |item|
        pdf.Cell(@col1_w, @row_h, "Item","L")
        pdf.Cell(@col2_w, @row_h, item.product_tree_code,"L")
        pdf.Cell(@col3_w, @row_h, item.name,"L")
        pdf.Cell(@col4_w, @row_h, item.rel_string, "L")
        pdf.Cell(@col5_w, @row_h, item.code,"LR")
        pdf.Ln
      end

      pdf.Cell(@col1_w, @row_h, " ","LB")
      pdf.Cell(@col2_w, @row_h, " ","LB")
      pdf.Cell(@col3_w, @row_h, " ","LB")
      pdf.Cell(@col4_w, @row_h, " ","LB")
      pdf.Cell(@col5_w, @row_h, " ","LBR")
      pdf.Ln
    end

    if @cm_delivered_docs.any?
      print_header_1(pdf) unless header_1_printed

      @cm_delivered_docs.each do |doc|
        pdf.Cell(@col1_w, @row_h, "Document","L")
        if doc.external_doc_id.empty?
          pdf.Cell(@col2_w, @row_h, doc.code,"L")
        else
          pdf.Cell(@col2_w, @row_h, doc.external_doc_id,"L")
        end
        
        if doc.name.length > @col_max
          pdf.Cell(@col3_w, @row_h, doc.name[0..@col_max],"L")
          pdf.Cell(@col4_w, @row_h, doc.rel_string, "L")
          pdf.Cell(@col5_w, @row_h, doc.code,"LR")
          pdf.Ln
          pdf.Cell(@col1_w, @row_h, " ","L")
          pdf.Cell(@col2_w, @row_h, " ","L")
          pdf.Cell(@col3_w, @row_h, doc.name[@col_max+1..@col_max*2],"L")
          pdf.Cell(@col4_w, @row_h, " ","L")
          pdf.Cell(@col5_w, @row_h, " ","LR")
        else
          pdf.Cell(@col3_w, @row_h, doc.name,"L")
          pdf.Cell(@col4_w, @row_h, doc.rel_string, "L")
          pdf.Cell(@col5_w, @row_h, doc.code,"LR")
        end
        pdf.Ln
      end

      pdf.Cell(@col1_w, @row_h, " ","LB")
      pdf.Cell(@col2_w, @row_h, " ","LB")
      pdf.Cell(@col3_w, @row_h, " ","LB")
      pdf.Cell(@col4_w, @row_h, " ","LB")
      pdf.Cell(@col5_w, @row_h, " ","LBR")
      pdf.Ln
    end

    if @cm_closed_ncs.any?
      print_header_2(pdf)
      header_2_printed=true

      print_ncs(pdf, "C", @cm_closed_ncs)
    end

    if @cm_delivered_ncs.any?
      print_header_2(pdf) unless header_2_printed

      print_ncs(pdf, "D", @cm_delivered_ncs)
    end

    if @cm_delivered_changes.any?
      @cm_delivered_changes.each do |ch|
        pdf.Cell(@col1_w, @row_h, "Change","L")
        pdf.Cell(@col2_w, @row_h, " ","L")
        pdf.Cell(@col3_w, @row_h, ch.name,"L")
        pdf.Cell(@col4_w, @row_h, ch.rel_string, "L")
        pdf.Cell(@col5_w, @row_h, ch.code,"LR")
        pdf.Ln
      end

      pdf.Cell(@col1_w, @row_h, " ","LB")
      pdf.Cell(@col2_w, @row_h, " ","LB")
      pdf.Cell(@col3_w, @row_h, " ","LB")
      pdf.Cell(@col4_w, @row_h, " ","LB")
      pdf.Cell(@col5_w, @row_h, " ","LBR")
      pdf.Ln
    end
   
    pdf.Output
  end

  private

  def write_project_line(pdf, chars_per_line, chain)

    # the first "chars_per_line" characters was written in main code
    rest_of_chain=chain.length - (chars_per_line + 1)
    # here we know that chain is greater than chars_per_line (controlled in main code)
    chain=chain[(chars_per_line + 1)..chain.length]

    while rest_of_chain > chars_per_line
      pdf.Cell(35, 5, " ","L")
      pdf.Cell(60, 5, chain[0..chars_per_line])
      pdf.Cell(35, 5, " ","L")
      pdf.Cell(60, 5, " ","R")
      pdf.Ln

      rest_of_chain=chain.length - (chars_per_line + 1)
      chain=chain[(chars_per_line + 1)..chain.length] if chain.length > chars_per_line
    end

    if chain.length > 0
      pdf.Cell(35, 5, " ","L")
      pdf.Cell(60, 5, chain)
      pdf.Cell(35, 5, " ","L")
      pdf.Cell(60, 5, " ","R")
      pdf.Ln
    end

  end

  def print_header_1(pdf)
    pdf.SetFontStyle('B',8)
    pdf.Cell(@col1_w, @row_h, "Type","LTB", 0, "C", 1)
    pdf.Cell(@col2_w, @row_h, "Identification","LTB", 0, "C", 1)
    pdf.Cell(@col3_w, @row_h, "Name/Title","LTB", 0, "C", 1)
    pdf.Cell(@col4_w, @row_h, "Version", "LTB", 0 ,"C", 1)
    pdf.Cell(@col5_w, @row_h, "DEIMOS Code","LTRB", 0, "C", 1)
    pdf.Ln

    pdf.SetFontStyle('',7,'FreeMono')
  end

  def print_header_2(pdf)
    pdf.Ln
    pdf.SetFontStyle('B',8)
    pdf.Cell(@col1_w, @row_h, "Type","LTB", 0, "C", 1)
    pdf.Cell(@col2_w, @row_h, "Identification","LTB", 0, "C", 1)
    pdf.Cell(@col3_w, @row_h, "Name/Title","LTB", 0, "C", 1)
    pdf.Cell(@col6_w, @row_h, "Open Date", "LTRB", 0 ,"C", 1)
    pdf.Ln

    pdf.SetFontStyle('',7,'FreeMono')
  end

  def print_ncs(pdf, type, ncs)
      ncs.each do |nc|
        if type == 'C'
          pdf.Cell(@col1_w, @row_h, "Closed NC","L")
        else
          pdf.Cell(@col1_w, @row_h, "Alive NC","L")
        end
        pdf.Cell(@col2_w, @row_h, nc.code,"L")

        if nc.name.length > @col_max
          pdf.Cell(@col3_w, @row_h, nc.name[0..@col_max],"L")
          pdf.Cell(@col6_w, @row_h, nc.created_on.strftime("%Y-%m-%d"),"LR")
          pdf.Ln
          pdf.Cell(@col1_w, @row_h, " ","L")
          pdf.Cell(@col2_w, @row_h, " ","L")
          pdf.Cell(@col3_w, @row_h, nc.name[@col_max+1..@col_max*2],"L")
          pdf.Cell(@col6_w, @row_h, " ","LR")
        else
          pdf.Cell(@col3_w, @row_h, nc.name,"L")
          pdf.Cell(@col6_w, @row_h, nc.created_on.strftime("%Y-%m-%d"),"LR")
        end
        pdf.Ln
      end

      pdf.Cell(@col1_w, @row_h, " ","LB")
      pdf.Cell(@col2_w, @row_h, " ","LB")
      pdf.Cell(@col3_w, @row_h, " ","LB")
      pdf.Cell(@col6_w, @row_h, " ","LBR")
      pdf.Ln
  end
end