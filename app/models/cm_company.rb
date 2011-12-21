class CmCompany < ActiveRecord::Base
  belongs_to :project

  before_destroy :check_integrity

  validates_length_of :code, :maximum => 30, :allow_nil => true
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  validates_format_of :mail, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :allow_blank => true
  validates_length_of :name, :maximum => 30

  COMPANY_TYPES = %w(Customer Subcontractor Collaborator Supplier Vendor Home Other)

  def to_s; name end

  private
  def check_integrity
    if CmNc.find(:first, :conditions => ["company_id=?", self.id])
      raise "Can't delete company because there are NCs using it!!"
    end
    if CmDelivery.find(:first, :conditions => ["from_company=? or to_company=?", self.id, self.id])
      raise "Can't delete company because there are deliveries using it!!"
    end
    if CmBoard.find(:first, :conditions => ["company_id=?", self.id])
      raise "Can't delete company because there are boards using it!!"
    end
  end
end