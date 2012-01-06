module IcuRatings
  class Improvers
    extend ActiveSupport::Memoizable
    Row = Struct.new(:player, :from, :upto, :diff, :age)

    def initialize(params)
      if available?
        @from = lists.index(params[:from]) if params[:from].present?
        @upto = lists.index(params[:upto]) if params[:upto].present?

        @upto ||= 0

        unless @from && @from > @upto
          if lists[@upto + 3]
            @from = @upto + 3
          elsif lists[@upto + 1]
            @from = @upto + 1
          else
            @from = lists.size - 1
            @upto = @from - 1
          end
        end
        
        params[:from] = lists[@from]
        params[:upto] = lists[@upto]
      end
    end

    def dates
      IcuRating.unscoped.select("DISTINCT(list)").order("list DESC").map(&:list)
    end

    def lists
      dates.map(&:to_s)
    end

    def rows
      players = IcuPlayer.unscoped.joins(:icu_ratings).includes(:icu_ratings)
      players = players.where("list IN (?)", [lists[@from], lists[@upto]]).order("list DESC")
      rows = players.inject([]) do |m, p|
        if p.icu_ratings.size == 2
          from = p.icu_ratings.last
          upto = p.icu_ratings.first
          diff = upto.rating - from.rating
          age  = p.age
          age  = nil unless age.to_i <= 21  # only show for juniors
          m.push Row.new(p, from, upto, diff, age)
        else
          m
        end
      end
      rows.sort{ |a, b| b.diff <=> a.diff || a.name <=> b.name }.first(20)
    end

    memoize :dates, :lists, :rows

    def available?
      lists.size > 1
    end

    def from
      dates[@from]
    end

    def upto
      dates[@upto]
    end
  end
end
