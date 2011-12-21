module CmReqsHelper
  def type_modified
    rtype=CmReqsType.find(:first, :conditions => ["id=?",
        params[:type_id].to_i])

    respond_to do |format|
      format.js do
        if rtype.soc_control
          render(:update) {|page|
            page.show "soc_fields" }
        else
          render(:update) {|page|
            page.hide "soc_fields" }
        end
      end
    end
  end
end