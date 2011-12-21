class CmDeliveryStatus < ActiveRecord::Base
  belongs_to :project

  before_destroy :check_integrity
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 50
  validate :just_one_default
  
  def self.default(project)
    find(:first, :conditions =>["is_default=? and project_id in (?,?)", true, 0, project])
  end

  def is_closed
    self.is_closed?
  end

  def is_opened
    not self.is_closed?
  end

  def to_s; name end

  private
  def check_integrity
    if CmDelivery.find(:first, :conditions => ["status_id=?", self.id])
      raise "Can't delete status beacuse there are deliveries using it!!"
    end
  end

  def just_one_default
    if(self.is_default)
      if new_record?
        @DeliveryStatus=CmDeliveryStatus.find(:first, :conditions =>["is_default=? and project_id in (?,?)",
            true, 0, self.project_id])
      else
        @DeliveryStatus=CmDeliveryStatus.find(:first, :conditions =>["is_default=? and id<>? and project_id in (?,?)",
            true, self.id, 0, self.project_id])
      end
      errors.add(:is_default, "already assigned to " + @DeliveryStatus.name) unless (@DeliveryStatus.nil?)
    end
  end
end