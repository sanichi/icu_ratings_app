module IcuRatings
  class WAR
    Row = Struct.new(:player, :icu, :fide, :average)

    def initialize(params)
      @maximum = 50
      @gender  = params[:gender]
      if params[:method] == "war"
        @rating_weight = [0.2, 0.3, 0.5]
        @type_weight = { icu: 0.6, fide: 0.4 }
      else
        @rating_weight = [1.0]
        @type_weight = { icu: 0.5, fide: 0.5 }
      end
    end

    def years
      @years ||= @rating_weight.size
    end

    def types
      @types ||= @type_weight.keys
    end

    def available?
      lists.select{ |type, list| list.size == years }.size == types.size
    end

    # Compute something like this: { icu: [date1, date2, date3], fide: [date1, date2, date3] }.
    def lists
      return @lists if @lists
      year = latest_common_year
      @lists = year ? types.inject({}) { |hash, type| hash[type] = lists_for(type, year); hash } : []
    end

    # Return an array of ordered Row objects for display, one row per player.
    def players
      return @players if @players

      # Get raw rating data, initially using a hash to tie ICU and FIDE ratings together for each player.
      rows = icu_players
      fide_players(rows)

      # Turn into an array and then calculate an average for each row.
      rows = rows.values
      rows.each do |row|
        average, weight = 0.0, 0.0
        average, weight = rating_average(row, average, weight, :icu)
        average, weight = rating_average(row, average, weight, :fide)
        row.average = weight > 0.0 ? average / weight : 0.0
      end

      # Sort the array.
      rows.sort! { |a,b| b.average <=> a.average }

      # Finally, truncate, cache and return.
      @players = rows[0..@maximum-1]
    end

    def methods_menu
      [["Simple average of latest ratings", "simple"], ["Three year weighted average", "war"]]
    end

    def gender_menu
      [["Men and Women", ""], ["Women only", "F"]]
    end

    private

    def lists_for(type, year)
      klass = type == :icu ? IcuRating : FideRating
      years.times.inject([]) do |arry, i|
        date = klass.unscoped.where("list LIKE '#{year - i}%'").maximum(:list)
        arry.unshift(date) if date
        arry
      end
    end

    def latest_common_year
      icu  = IcuRating.unscoped.maximum(:list).try(:year)
      fide = FideRating.unscoped.maximum(:list).try(:year)
      return unless icu && fide
      icu <= fide ? icu : fide
    end

    def icu_players
      threshold = @gender == "F" ? 1000 : 1800
      players = IcuPlayer.unscoped.joins(:icu_ratings).includes(:icu_ratings)
      players = players.where("fed = 'IRL' OR fed IS NULL").where(deceased: false)
      players = players.where("list IN (?)", lists[:icu]).where("full = 1").where("rating >= #{threshold}")
      players = players.where("gender = 'F'") if @gender == "F"
      players.inject({}) do |phash, player|
        row = Row.new(player)
        row.icu = player.icu_ratings.inject({}) { |rhash, icu_rating| rhash[icu_rating.list] = icu_rating.rating; rhash }
        row.fide = {}
        phash[player.id] = row
        phash
      end
    end

    def fide_players(rows)
      players = FidePlayer.unscoped.joins(:fide_ratings).includes(:fide_ratings)
      players = players.where("icu_id IN (?)", rows.keys)
      players = players.where("list IN (?)", lists[:fide])
      players.each do |player|
        row = rows[player.icu_id]
        player.fide_ratings.each { |fide_rating| row.fide[fide_rating.list] = fide_rating.rating }
      end
    end

    def rating_average(row, average, weight, type)
      av, wt = 0.0, 0.0
      lists[type].each_with_index do |list, i|
        rating = row.send(type)[list]
        if rating
          av += @rating_weight[i] * rating
          wt += @rating_weight[i]
        end
      end
      if wt > 0.0
        average += @type_weight[type] * av / wt
        weight  += @type_weight[type]
      end
      [average, weight]
    end
  end
end
