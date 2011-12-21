class CmSourceFile < ActiveRecord::Base
  belongs_to :project

  validates_uniqueness_of :file_name, :scope => :project_id

  def to_s; self.id.to_s end
end
