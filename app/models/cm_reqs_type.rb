class CmReqsType < ActiveRecord::Base
  before_destroy :check_integrity
  belongs_to :project

  validates_presence_of :name, :level
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 30
  validate :just_one_default

  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
  end

  def to_s; name end

  private

  def just_one_default
    if(self.is_default)
      if new_record?
        @reqType=CmReqsType.find(:first, :conditions =>["is_default=? and project_id in (?,?)",
            true, 0, self.project_id])
      else
        @reqType=CmReqsType.find(:first, :conditions =>["is_default=? and id<>? and project_id in (?,?)",
            true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @reqType.name) unless (@reqType.nil?)
    end
  end

  def check_integrity
    if CmReq.find(:first, :conditions => ["type_id=?", self.id])
      raise "Can't delete Type because there are Reqs using it!!"
    end
  end
end