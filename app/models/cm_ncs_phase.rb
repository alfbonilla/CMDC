class CmNcsPhase < ActiveRecord::Base
  before_destroy :check_integrity
  belongs_to :project

  validates_presence_of :name
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
        @ncPhase=CmNcsPhase.find(:first,
          :conditions =>["is_default=? and project_id in (?,?)", true, 0, self.project_id])
      else
        @ncPhase=CmNcsPhase.find(:first,
          :conditions =>["is_default=? and id<>? and project_id in (?,?)", true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @ncPhase.name) unless (@ncPhase.nil?)
    end
  end

  def check_integrity
    if CmNc.find(:first, :conditions => ["phase_id=?", self.id])
      raise "Can't delete Phase because there are NCs using it!!"
    end
  end
end