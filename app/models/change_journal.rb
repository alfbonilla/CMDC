class ChangeJournal < Journal
    belongs_to :cm_change, :foreign_key => :journalized_id
    
    acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "##{o.cm_change.id}#{status}: #{o.cm_change.name}" },
                  :description => :notes,
                  :author => :user,
                  :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'cm_change-closed' : 'cm_change-edit') : 'cm_change-note' },
                  :url => Proc.new {|o| {:controller => 'cm_changes', :action => 'show', :id => o.cm_change.id, :anchor => "change-#{o.id}"}}
  
    acts_as_activity_provider :type => 'cm_changes',
                              :permission => :view_cm_changes,
                              :author_key => :user_id,
                              :find_options => {:include => [{:cm_change => :project}, :details, :user],
                                                :conditions => "#{Journal.table_name}.journalized_type = 'Change' AND" +
                                                               " (#{JournalDetail.table_name}.prop_key = 'status_id' OR #{Journal.table_name}.notes <> '')"}
    
    def save(*args)
      # Do not save an empty journal
      (details.empty? && notes.blank?) ? false : super
    end
    
    # Returns the new status if the journal contains a status change, otherwise nil
    def new_status
      c = details.detect {|detail| detail.prop_key == 'status_id'}
      (c && c.value) ? CmChangeStatus.find_by_id(c.value.to_i) : nil
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
