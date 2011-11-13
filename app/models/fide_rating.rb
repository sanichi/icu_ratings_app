class FideRating < ActiveRecord::Base
  belongs_to :fide_player, foreign_key: "fide_id"
  
  validates_numericality_of :fide_id, only_integer: true, greater_than: 0
  validates_numericality_of :rating, only_integer: true, greater_than: 0, less_than: 3000
  validates_numericality_of :games, only_integer: true, greater_than_or_equal_to: 0, less_than: 100
  validates_date            :period, on_or_after: '1950-01-01'
  validates_uniqueness_of   :period, scope: :fide_id
  validate                  :period_should_be_first_of_month
  
  def period_should_be_first_of_month
    errors.add(:period, "should be 1st day of month") unless period.day == 1
  end
end
