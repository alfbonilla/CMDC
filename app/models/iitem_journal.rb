class IitemJournal < Journal

    belongs_to :cm_item, :foreign_key => :journalized_id
    
    acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "##{o.cm_item.id}#{status}: #{o.cm_item.name}" },
                  :description => :notes,
                  :author => :user,
                  :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'cm_item-closed' : 'cm_item-edit') : 'cm_item-note' },
                  :url => Proc.new {|o| {:controller => 'cm_items', :action => 'show', :id => o.cm_item.id, :anchor => "change-#{o.id}"}}
  
    acts_as_activity_provider :type => 'cm_items',
                              :permission => :view_cm_items,
                              :author_key => :user_id,
                              :find_options => {:include => [{:cm_item => :project}, :details, :user],
                                                :conditions => "#{Journal.table_name}.journalized_type = 'Inventory Item' AND" +
                                                               " (#{JournalDetail.table_name}.prop_key = 'status_id' OR #{Journal.table_name}.notes <> '')"}
    
    def save(*args)
      # Do not save an empty journal
      (details.empty? && notes.blank?) ? false : super
    end
    
    # Returns the new status if the journal contains a status change, otherwise nil
    def new_status
      c = details.detect {|detail| detail.prop_key == 'status_id'}
      (c && c.value) ? CmItemStatus.find_by_id(c.value.to_i) : nil
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
