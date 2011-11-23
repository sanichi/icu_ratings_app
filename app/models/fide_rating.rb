class FideRating < ActiveRecord::Base
  extend Util::Pagination

  belongs_to :fide_player, foreign_key: "fide_id"

  validates_numericality_of :fide_id, only_integer: true, greater_than: 0
  validates_numericality_of :rating, only_integer: true, greater_than: 0, less_than: 3000
  validates_numericality_of :games, only_integer: true, greater_than_or_equal_to: 0, less_than: 100
  validates_date            :period, on_or_after: "1950-01-01"
  validates_uniqueness_of   :period, scope: :fide_id
  validate                  :period_should_be_first_of_month

  default_scope includes(:fide_player).joins(:fide_player).order("period DESC, fide_ratings.rating DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where(period: params[:period]) if params[:period].present?
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("gender = ?", params[:gender]) if params[:gender].present?
    matches = matches.where(fide_id: params[:fide_id].to_i) if params[:fide_id].to_i > 0
    paginate(matches, path, params)
  end

  def self.periods
    unscoped.select("DISTINCT(period)").order("period DESC").map(&:period)
  end

  private

  def period_should_be_first_of_month
    errors.add(:period, "should be 1st day of month") unless period.day == 1
  end
end
