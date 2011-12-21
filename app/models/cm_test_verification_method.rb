class CmTestVerificationMethod < ActiveRecord::Base
  before_destroy :check_integrity

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validate :just_one_default

  def self.default
    find(:first, :conditions =>["is_default=?", true])
  end

  def to_s; name end

  private

  def just_one_default
    if(self.is_default)
      vm=CmTestVerificationMethod.find(:first, :conditions =>["is_default=?", true])
      errors.add(:is_default, "already assigned to " + vm.name) unless (vm.nil?)
    end
  end

  def check_integrity
    to=CmTestsObject.find(:first, :conditions => ["relation_integer=? and x_type=?",
          self.id, "CmReq"])
    if to
      raise "Can't delete Verification Method because is used by Test " + to.cm_test.code
    end
  end
end