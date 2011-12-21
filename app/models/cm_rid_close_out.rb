class CmRidCloseOut < ActiveRecord::Base
  before_destroy :check_integrity
  belongs_to :project

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 50
  validates_format_of :name, :with => /^[\w\s\'\-]*$/i
  validate :just_one_default

  # Returns the default status for new issues
  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
  end

  def is_closed
    self.is_closed?
  end

  def to_s; name end
  
  private

  def just_one_default
    if(self.is_default)
      if new_record?
        @ridcloseout=CmRidCloseOut.find(:first,
          :conditions =>["is_default=? and project_id in (?,?)", true, 0, self.project_id])
      else
        @ridcloseout=CmRidCloseOut.find(:first,
          :conditions =>["is_default=? and id <>? and project_id in (?,?)", true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @ridcloseout.name) unless (@ridcloseout.nil?)
    end
  end

  def check_integrity
    if CmRid.find(:first, :conditions => ["close_out_id=?", self.id])
      raise "Can't delete close out value because there are RIDs using it!!"
    end
  end
end