class CmItemGroup < ActiveRecord::Base
  belongs_to :project

  before_destroy :check_integrity

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  validates_length_of :name, :maximum => 30

  def to_s; name end

  private
  def check_integrity
    if CmItem.find(:first, :conditions => ["cm_item_group_id=?", self.id])
      raise "Can't delete group because there are Items using it!!"
    end
  end
 
end