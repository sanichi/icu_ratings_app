# == Schema Information
#
# Table name: publications
#
#  id              :integer(4)      not null, primary key
#  rating_list_id  :integer(4)
#  created_at      :datetime
#  updated_at      :datetime
#

class Publication < ActiveRecord::Base
  belongs_to :rating_list

  attr_accessible # none

  validates_numericality_of :rating_list_id, only_integer: true, greater_than: 0
end
