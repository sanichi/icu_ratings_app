# == Schema Information
#
# Table name: publications
#
#  id              :integer(4)      not null, primary key
#  rating_list_id  :integer(4)
#  report          :text
#  notes           :text
#  total           :integer(3)
#  creates         :integer(3)
#  remains         :integer(3)
#  updates         :integer(3)
#  deletes         :integer(3)
#  created_at      :datetime
#

class Publication < ActiveRecord::Base
  belongs_to :rating_list
  belongs_to :last_tournament, class_name: "Tournament"

  STATS = [:total, :creates, :remains, :updates, :deletes]

  validates :rating_list_id, numericality: { only_integer: true, greater_than: 0 }
  validates :last_tournament_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :total, :creates, :remains, :updates, :deletes, numericality: { only_integer: true, greater_than_or_equal: 0 }
  validates :report, presence: true

  default_scope -> { order(created_at: :desc) }
end
