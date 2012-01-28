module IcuRatings
  class Graph
    attr_reader :title, :width, :height, :onload
    Point = Struct.new(:list, :label, :rating, :selected)

    def initialize(input, opt={})
      case input
      when User
        @icu_player  = input.icu_player
      when IcuRating
        @icu_player  = input.icu_player
        @icu_list    = input.list
      when FideRating
        @fide_player = input.fide_player
        @fide_list   = input.list
      when FidePlayer
        @fide_player = input
      when IcuPlayer
        @icu_player  = input
      end

      player = @icu_player || @fide_player
      @title = player.name(:reversed, :title, :brackets) if player

      @icu_player  ||= @fide_player.icu_player if @fide_player
      @fide_player ||= @icu_player.fide_player if @icu_player

      @width  = opt[:width]  || 700
      @height = opt[:height] || 300

      @onload = opt[:onload]
    end

    def icu_ratings
      return [] unless @icu_player
      @icu_ratings ||= IcuRating.where("icu_players.id = ?", @icu_player.id).map do |r|
        Point.new(decimal_year(r.list), r.list.strftime('%Y %b'), r.rating, @icu_list == r.list)
      end
    end

    def fide_ratings
      return [] unless @fide_player
      @fide_ratings ||= FideRating.where("fide_players.id = ?", @fide_player.id).map do |r|
        Point.new(decimal_year(r.list), r.list.strftime('%Y %b'), r.rating, @fide_list == r.list)
      end
    end

    def available?
      icu_ratings.size > 0 || fide_ratings.size > 0
    end

    def min_rating
      @min_rating ||= limit(:rating, 1000) { |m, r| r < m }
    end

    def max_rating
      @max_rating ||= limit(:rating, 2000) { |m, r| r > m }
    end

    def rating_range
      return @rating_range if @rating_range
      min = (min_rating / 100.0).floor * 100
      max = (max_rating / 100.0).ceil  * 100
      min, max = min - 100, max + 100 if min == max
      @rating_range = [min, max]
    end

    def first_list
      @first_list ||= limit(:list, Date.today.year) { |m, d| d < m }
    end

    def last_list
      @last_list ||= limit(:list, Date.today.year) { |m, d| d > m }
    end

    def list_range
      return @list_range if @list_range
      min = first_list.floor
      max = last_list.ceil
      min, max = min - 1, max + 1 if min == max
      @list_range ||= [min, max]
    end

    private

    def limit(method, default)
      (icu_ratings + fide_ratings).inject(nil) { |m, r| v = r.send(method); m = v if !m || yield(m, v); m } || default
    end

    def decimal_year(date)
      date.year + date.month / 13.0
    end
  end
end
