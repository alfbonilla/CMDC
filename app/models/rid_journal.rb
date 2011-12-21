class RidJournal < Journal
    belongs_to :cm_rid, :foreign_key => :journalized_id
    
    acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "##{o.cm_rid.id}}: #{o.cm_rid.name}" },
                  :description => :notes,
                  :author => :user,
                  :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'cm_rid-closed' : 'cm_rid-edit') : 'cm_rid-note' },
                  :url => Proc.new {|o| {:controller => 'cm_rids', :action => 'show', :id => o.cm_rid.id, :anchor => "Rid-#{o.id}"}}
     
    def save(*args)
      # Do not save an empty journal
      (details.empty? && notes.blank?) ? false : super
    end
    
    # Returns the new status if the journal contains a status Rid, otherwise nil
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
