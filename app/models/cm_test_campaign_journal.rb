class CmTestCampaignJournal < Journal

  belongs_to :cm_test_campaign, :foreign_key => :journalized_id
  has_many :journals, :as => :journalized, :dependent => :destroy

  acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "##{o.cm_test_campaign.id}#{status}: #{o.cm_test_campaign.code}" },
                :description => :notes,
                :author => :user,
:type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'cm_test_campaign-closed' : 'cm_test_campaign-edit') : 'cm_test_campaign-note' },
                :url => Proc.new {|o| {:controller => 'cm_test_campaign', :action => 'show', :id => o.cm_test_campaign.id, :anchor => "change-#{o.id}"}}


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