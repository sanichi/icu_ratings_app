class RatingsGraph
  attr_reader :icu_player, :width, :height, :onload
  extend ActiveSupport::Memoizable
  Point = Struct.new(:list, :label, :rating)

  def initialize(input, opt={})
    @icu_player =
      case input
      when User, FidePlayer then input.icu_player
      when IcuPlayer        then input
      else nil
    end
    @width  = opt[:width]  || 700
    @height = opt[:height] || 300
    @onload = opt[:onload]
  end

  def icu_ratings
    return [] unless @icu_player
    IcuRating.where("icu_players.id = ?", @icu_player.id).map do |r|
      Point.new(decimal_year(r.list), r.list.strftime('%Y %b'), r.rating)
    end
  end

  def fide_ratings
    return [] unless @icu_player
    FideRating.where("fide_players.icu_id = ?", @icu_player.id).map do |r|
      Point.new(decimal_year(r.period), r.period.strftime('%Y %b'), r.rating)
    end
  end

  def available?
    icu_ratings.size > 0 || fide_ratings.size > 0
  end

  def min_rating
    limit(:rating, 1000) { |m, r| r < m }
  end

  def max_rating
    limit(:rating, 2000) { |m, r| r > m }
  end

  def rating_range
    min = (min_rating / 100.0).floor * 100
    max = (max_rating / 100.0).ceil  * 100
    min, max = min - 100, max + 100 if min == max
    [min, max]
  end

  def first_list
    limit(:list, Date.today.year) { |m, d| d < m }
  end

  def last_list
    limit(:list, Date.today.year) { |m, d| d > m }
  end

  def list_range
    min = first_list.floor
    max = last_list.ceil
    min, max = min - 1, max + 1 if min == max
    [min, max]
  end

  memoize :icu_ratings, :fide_ratings
  memoize :min_rating, :max_rating, :rating_range
  memoize :first_list, :last_list, :list_range

  private

  def limit(method, default)
    (icu_ratings + fide_ratings).inject(nil) { |m, r| v = r.send(method); m = v if !m || yield(m, v); m } || default
  end

  def decimal_year(date)
    date.year + date.month / 13.0
  end
end