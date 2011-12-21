class CmTestsTest < ActiveRecord::Base
  belongs_to :parent_test, :class_name => 'CmTest', :foreign_key => 'cm_test_id'
  belongs_to :child_test, :class_name => 'CmTest', :foreign_key => 'child_test_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  #TEST_RELATIONS = %w(belongs_to_stock integrated_in installed_on)

#  validates_presences_of :cm_test_id, :child_test_id
#  validates_uniqueness_of :child_test_id, :scope => [:child_test_id, :cm_test_id]
#  validate :no_with_itself
  #validates_inclusion_of :priority, :in => TEST_RELATIONS

  

#  def no_with_itself
#    if self.child_test_id == self.cm_test_id
#      errors.add(:child_test_id, "can't be the same than origin")
#    end
#  end

  def to_s; description end
end
