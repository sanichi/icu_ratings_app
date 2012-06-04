module Pages
  class MyHome
    GainLoss = Struct.new(:gain, :loss, :gains, :losses, :any, :max)

    def initialize(id)
      @id = id
      @max_rec = 4  # max number of recent tournaments
      @max_tgl = 10  # max tournament gains and losses
      @max_ggl = 10  # max game gains and losses
    end
    
    def max_rec
      @max_rec
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
      @tgl.any = @tgl.gains || @tgl.losses
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
      @ggl.any = @ggl.gains || @ggl.losses
      @ggl.max = @ggl.gain.size > @ggl.loss.size ? @ggl.gain.size : @ggl.loss.size
      @ggl
    end
  end
end
