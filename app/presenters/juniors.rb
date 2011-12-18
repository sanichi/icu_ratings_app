class Juniors
  attr_reader :date
  extend ActiveSupport::Memoizable

  def initialize(params)
    params[:under] = under_range.first unless params[:under].present? && under_range.include?(params[:under])
    params[:least] = least_range.last  unless params[:least].present? && least_range.include?(params[:least])
    params[:date]  = Date.today.to_s   unless params[:date].present?  && date_range.include?(params[:date])

    @date  = Date.parse(params[:date])
    @under = @date.years_ago(params[:under].to_i)
    @least = @date.years_ago(params[:least].to_i)

    @gender = params[:gender]
  end

  def list
    IcuRating.unscoped.maximum(:list)
  end

  def under_range
    (8..21).map(&:to_s).reverse
  end

  def least_range
    (8..20).map(&:to_s).reverse.push("0")
  end

  def date_range
    today = Date.today
    first = today.beginning_of_month
    range = []
    6.times.each { |m| range.push first.months_ago(6 - m) }
    range.push first
    range.push today unless today == first
    6.times.each { |m| range.push first.months_since(m + 1) }
    range.map(&:to_s)
  end

  def ratings
    return [] unless available?
    ratings = IcuRating.unscoped.order("rating DESC, dob DESC").includes(:icu_player)
    ratings = ratings.where(list: list).where("icu_players.fed = 'IRL' OR icu_players.fed IS NULL")
    ratings = ratings.where("icu_players.gender = 'M' OR icu_players.gender IS NULL") if @gender == "M"
    ratings = ratings.where("icu_players.gender = 'F'") if @gender == "F"
    ratings = ratings.where("icu_players.dob >  ?", @under)
    ratings = ratings.where("icu_players.dob <= ?", @least)
    ratings
  end

  memoize :list, :under_range, :least_range, :date_range, :ratings

  def available?
    list ? true : false
  end

  def under_menu
    under_range.map { |y| [y, y] }
  end

  def least_menu
    least_range.map { |y| [y, y] }
  end

  def date_menu
    today = Date.today.to_s
    date_range.inject([]) { |m, d| m.push [d == today ? "Today" : d, d] }
  end
end
