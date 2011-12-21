class CmDeliveriesObject < ActiveRecord::Base
  belongs_to :delivery, :class_name => 'CmDelivery', :foreign_key => 'cm_delivery_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  OBJECT_TYPES = %w(CmItem CmDoc CmNcClosed CmNc CmChange)

  validates_presence_of :cm_delivery_id, :x_id, :x_type

  def to_s; id.to_s end
end
