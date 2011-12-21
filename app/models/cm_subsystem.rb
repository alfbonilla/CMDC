class CmSubsystem < ActiveRecord::Base
  belongs_to :project

  validates_length_of :code, :maximum => 10, :allow_nil => true
  validates_presence_of :name
  validates_uniqueness_of :code, :name, :scope => :project_id
  validates_length_of :name, :maximum => 30

  def to_s; name end

end