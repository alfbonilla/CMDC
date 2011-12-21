class CmItemStatus < ActiveRecord::Base
    before_destroy :check_integrity
    belongs_to :project
  
    validates_presence_of :name
    validates_uniqueness_of :name, :scope => :project_id
    validates_length_of :name, :maximum => 30
    validates_format_of :name, :with => /^[\w\s\'\-]*$/i
    validate :just_one_default
     
    # Returns the default status for new issues
    def self.default(project)
      find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
    end

    def to_s; name end
  
  private

  def just_one_default
    if(self.is_default)
      if new_record?
        @iitemStatus=CmItemStatus.find(:first,
          :conditions =>["is_default=? and project_id in (?,?)", true, 0, self.project_id])
      else
        @iitemStatus=CmItemStatus.find(:first,
          :conditions =>["is_default=? and id<>? and project_id in (?,?)",
                true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @iitemStatus.name) unless (@iitemStatus.nil?)
    end
  end

    def check_integrity
      if CmItem.find(:first, :conditions => ["status_id=?", self.id])
        raise "Can't delete status because there are Items using it!!"
      end
    end
end