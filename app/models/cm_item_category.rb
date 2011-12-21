class CmItemCategory < ActiveRecord::Base
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
        @iitemCategory=CmItemCategory.find(:first,
          :conditions =>["is_default=? and project_id in (?,?)", true, 0, self.project_id])
      else
        @iitemCategory=CmItemCategory.find(:first,
          :conditions =>["is_default=? and id<>? and project_id in (?,?)",
            true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @iitemCategory.name) unless (@iitemCategory.nil?)
    end
  end

  def check_integrity
    if CmItem.find(:first, :conditions => ["category_id=?", self.id])
      raise "Can't delete Category because there are Items using it!!"
    end
  end
end