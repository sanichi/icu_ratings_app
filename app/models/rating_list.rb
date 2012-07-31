# == Schema Information
#
# Table name: rating_lists
#
#  id         :integer(4)      not null, primary key
#  date       :date
#  created_at :datetime
#  updated_at :datetime
#

class RatingList < ActiveRecord::Base
  extend ICU::Util::Pagination

  has_many :publications, dependent: :destroy

  attr_accessible :date

  validates_date :date, on_or_after: "2012-01-01", on_or_before: :today
  validates      :date, list_date: true

  default_scope order("date DESC")

  def self.auto_populate
    have = all.inject({}) { |h, l| h[l.date] = true; h }
    date = Date.new(2012, 1, 1)  # first list of this new rating system
    high = Date.today
    todo = []
    while date <= high
      todo.push(date) unless have[date]
      date = date >> 4
    end
    todo.each { |date| create(date: date) }
  end

  def self.search(params, path)
    matches = scoped
    matches = matches.where("date LIKE '#{params[:year]}%'") if params[:year].present?
    paginate(matches, path, params)
  end
end
