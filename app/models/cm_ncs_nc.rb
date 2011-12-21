class CmNcsNc < ActiveRecord::Base
  belongs_to :parent_nc, :class_name => 'CmNc', :foreign_key => 'cm_nc_id'
  belongs_to :child_nc, :class_name => 'CmNc', :foreign_key => 'child_nc_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  
  validates_presence_of :cm_nc_id, :child_nc_id
  validates_uniqueness_of :child_nc_id, :scope => [:child_nc_id, :cm_nc_id]
  validate :no_with_itself

  def no_with_itself
    if self.child_nc_id == self.cm_nc_id
      errors.add(:child_nc_id, "can't be the same than origin")
    end
  end

  def to_s; description end
end
