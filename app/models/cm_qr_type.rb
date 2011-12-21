class CmQrType < ActiveRecord::Base
  before_destroy :check_integrity

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30

  def to_s; name end

  private
  def check_integrity
    if CmQr.find(:first, :conditions => ["type_id=?", self.id])
      raise "Can't delete type because there are QRs using it!!"
    end
  end
 
end