module IcuRatings
  class Juniors
    attr_reader :date

    def initialize(params)
      params[:under] = under_range.first unless params[:under].present? && under_range.include?(params[:under])
      params[:least] = least_range.last  unless params[:least].present? && least_range.include?(params[:least])
      params[:date]  = Date.today.to_s   unless params[:date].present?  && date_range.include?(params[:date])

      @date  = Date.parse(params[:date])
      @under = @date.years_ago(params[:under].to_i)
      @least = @date.years_ago(params[:least].to_i)

      @gender = params[:gender]
      @club = params[:club]
    end

    def list
      @list ||= IcuRating.unscoped.maximum(:list)
    end

    def under_range
      @under_range ||= (8..21).map(&:to_s).reverse
    end

    def least_range
      @least_range ||= (8..20).map(&:to_s).reverse.push("0")
    end

    def date_range
      return @date_range if @date_range
      today = Date.today
      date = today.beginning_of_year
      last = date.next_year
      range = []
      while date <= last
        range.push date
        range.push today if date.year == today.year && date.month == today.month && date.day != today.day
        date = date.next_month
      end
      @date_range = range.map(&:to_s)
    end

    def ratings
      return @ratings if @ratings
      return [] unless available?
      @ratings = IcuRating.unscoped.order("rating DESC, dob DESC").includes(:icu_player)
      @ratings = ratings.where(list: list).where("icu_players.fed = 'IRL' OR icu_players.fed IS NULL")
      @ratings = ratings.where("icu_players.gender = 'M' OR icu_players.gender IS NULL") if @gender == "M"
      @ratings = ratings.where("icu_players.gender = 'F'") if @gender == "F"
      @ratings = ratings.where("icu_players.club = ?", @club) if @club.present?
      @ratings = ratings.where("icu_players.dob >  ?", @under)
      @ratings = ratings.where("icu_players.dob <= ?", @least)
      @ratings
    end

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
end
