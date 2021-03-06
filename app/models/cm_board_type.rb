class CmBoardType < ActiveRecord::Base
  belongs_to :project

  before_destroy :check_integrity
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 20
  validate :just_one_default
  
  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
  end

  def to_s; name end

  private
  def check_integrity
    if CmBoard.find(:first, :conditions => ["type_id=? and project_id=?", self.id, self.project_id])
      raise "Can't delete type because there are boards using it!!"
    end
  end

  def just_one_default
    if(self.is_default)
      if new_record?
        @boardType=CmBoardType.find(:first, :conditions =>["is_default=? and project_id in (?, ?)",
            true, 0, self.project_id])
      else
        @boardType=CmBoardType.find(:first, :conditions =>["is_default=? and id<>? and project_id in (?, ?)",
            true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @boardType.name) unless (@boardType.nil?)
    end
  end
end