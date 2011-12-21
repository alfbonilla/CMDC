class CmDocCounter < ActiveRecord::Base
  belongs_to :project
  
  validates_uniqueness_of :name, :scope => :project_id
  validates_presence_of :name
  validates_numericality_of :counter

  # Counters allowed for cmdc object: All (0) and the own object (x)
  named_scope :my_project, lambda { |project| {:conditions =>
        ["#{CmDocCounter.table_name}.project_id=?", project]}}
  named_scope :object_counters, lambda { |cmdc_obj| {:conditions =>
        ["#{CmDocCounter.table_name}.cmdc_object=? or \
          #{CmDocCounter.table_name}.cmdc_object=?", 0, cmdc_obj],
        :order => 'cmdc_object DESC'}}

  def to_s
    self.name
  end
end
