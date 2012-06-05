module Pages
  class MyHome
    GainLoss = Struct.new(:gain, :loss, :gains, :losses, :max)

    def initialize(id)
      @id = id
      @max_rec = 4  # max number of recent tournaments
      @max_tgl = 10  # max tournament gains and losses
      @max_ggl = 10  # max game gains and losses
    end

    def published_ratings?
      icu_ratings.size > 0 || fide_ratings.size > 0
    end

    def published_icu_ratings?
      icu_ratings.size > 0
    end

    def recent_ratings?
      recent_trns.size > 0
    end

    def trn_gains_and_losses?
      trn_gains_and_losses.gains || trn_gains_and_losses.losses
    end

    def game_gains_and_losses?
      game_gains_and_losses.gains || game_gains_and_losses.losses
    end

    def anything_missing?
      !published_icu_ratings? || !recent_ratings?
    end

    def icu_ratings
      return @icu_ratings if @icu_ratings
      @icu_ratings = []
      latest = IcuRating.get_rating(@id, :latest)
      if latest
        @icu_ratings.push latest
        @icu_ratings.push IcuRating.get_rating(@id, :highest)
        @icu_ratings.push IcuRating.get_rating(@id, :lowest)
      end
      @icu_ratings
    end

    def fide_ratings
      return @fide_ratings if @fide_ratings
      @fide_ratings = []
      fide_player = FidePlayer.find_by_icu_id(@id)
      if fide_player
        id = fide_player.id
        latest = FideRating.get_rating(id, :latest)
        if latest
          @fide_ratings.push latest
          @fide_ratings.push FideRating.get_rating(id, :highest)
          @fide_ratings.push FideRating.get_rating(id, :lowest)
        end
      end
      @fide_ratings
    end

    def recent_trns
      @recent_trns ||= Player.get_players(@id, :recent, @max_rec)
    end

    def trn_gains_and_losses
      return @tgl if @tgl
      @tgl = GainLoss.new
      @tgl.gain = Player.get_players(@id, :gain, @max_tgl)
      @tgl.loss = Player.get_players(@id, :loss, @max_tgl)
      @tgl.gains = @tgl.gain.size > 0
      @tgl.losses = @tgl.loss.size > 0
      @tgl.max = @tgl.gain.size > @tgl.loss.size ? @tgl.gain.size : @tgl.loss.size
      @tgl
    end

    def game_gains_and_losses
      return @ggl if @ggl
      @ggl = GainLoss.new
      @ggl.gain = Result.get_results(@id, :gain, @max_ggl)
      @ggl.loss = Result.get_results(@id, :loss, @max_ggl)
      @ggl.gains = @ggl.gain.size > 0
      @ggl.losses = @ggl.loss.size > 0
      @ggl.max = @ggl.gain.size > @ggl.loss.size ? @ggl.gain.size : @ggl.loss.size
      @ggl
    end

    def inherited_rating
      return @inherited_rating.first if @inherited_rating
      @inherited_rating = []
      @inherited_rating.push OldRating.find_by_icu_id(@id)
      @inherited_rating.first
    end

    def max_rec
      @max_rec
    end
  end
end
