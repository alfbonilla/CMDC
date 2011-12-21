class CmNcsObject < ActiveRecord::Base
  belongs_to :cm_nc, :class_name => 'CmNc', :foreign_key => 'cm_nc_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :item, :class_name => 'CmItem', :foreign_key => 'x_id'
  belongs_to :req, :class_name => 'CmReq', :foreign_key => 'x_id'
  belongs_to :doc, :class_name => 'CmDoc', :foreign_key => 'x_id'
  belongs_to :test_record, :class_name => 'CmTestRecord', :foreign_key => 'x_id'
  belongs_to :target_version, :class_name => 'Version', :foreign_key => 'target_version_id'
  
  OBJECT_TYPES = %w(CmBoard CmItem CmDoc CmReq CmTestRecord)

  validate :fields_on_type
  validates_presence_of :cm_nc_id, :x_id, :x_type

  def fields_on_type
    if self.x_type == "CmBoard"
      errors.add(:target_version_id, ":Target Version is a mandatory field") if self.target_version.blank?
      
      if self.cm_nc.classification.name == "major" and self.rel_string == "Use_as_is"
        x = CmBoardsIssue.find(:first, :conditions => ['cm_board_id = ?', self.x_id])
        errors.add(:rel_string, 
          ":Major NCs with Use As Is decision requires to create some related Action") if x.blank?

        if self.rel_string == "Use_as_is"
          #Search for CHANGE type RFD/RFW
        end

      end
    end

  end

  def to_s; id.to_s end
end
