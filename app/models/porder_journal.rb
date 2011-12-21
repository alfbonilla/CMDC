class PorderJournal < Journal

    belongs_to :puchase_order, :foreign_key => :journalized_id
    
    acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "##{o.cm_purchase_order.id}#{status}: #{o.cm_purchase_order.name}" },
                  :description => :notes,
                  :author => :user,
  :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'cm_purchase_order-closed' : 'cm_purchase_order-edit') : 'cm_purchase_order-note' },
                  :url => Proc.new {|o| {:controller => 'cm_purchase_orders', :action => 'show', :id => o.cm_purchase_order.id, :anchor => "change-#{o.id}"}}
  
    acts_as_activity_provider :type => 'cm_purchase_orders',
                              :permission => :view_cm_purchase_orders,
                              :author_key => :user_id,
                              :find_options => {:include => [{:cm_purchase_order => :project}, :details, :user],
                                                :conditions => "#{Journal.table_name}.journalized_type = 'Purchase Order' AND" +
                                                               " (#{JournalDetail.table_name}.prop_key = 'status_id' OR #{Journal.table_name}.notes <> '')"}
    
    def save(*args)
      # Do not save an empty journal
      (details.empty? && notes.blank?) ? false : super
    end
    
    # Returns the new status if the journal contains a status change, otherwise nil
    # Purchase Order has not status associated, so returns nil
    def new_status
        nil
    end
    
    def new_value_for(prop)
      c = details.detect {|detail| detail.prop_key == prop}
      c ? c.value : nil
    end
    
    def editable_by?(usr)
      true
    end
    
    def project
      journalized.respond_to?(:project) ? journalized.project : nil
    end

    def attachments
      journalized.respond_to?(:attachments) ? journalized.attachments : nil
    end
  end
