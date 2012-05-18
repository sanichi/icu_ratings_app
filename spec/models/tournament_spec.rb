require 'spec_helper'

describe Tournament do
  context "#name_with_year" do
    it "should add years to end of name" do
      t = Tournament.new
      t.name = "Masters"
      t.start = "2012-05-12"
      t.name_with_year.should == "Masters 2012"
      t.finish = "2012-05-13"
      t.name_with_year.should == "Masters 2012"
      t.finish = "2013-05-13"
      t.name_with_year.should == "Masters 2012-13"
    end
  end

  context "#icu_tournament" do
    def player_signature(t, n)
      p = t.player(n)
      sig = Array.new
      %w[num rank first_name last_name fed title gender rating fide_rating id fide_id dob].each { |attr| sig << p.send(attr) }
      p.results.each do |r|
        rsig = %w[round score colour].map { |attr| r.send(attr) }.join('')
        rsig.concat(r.rateable ? 'r' : 'u')
        if r.opponent
          o = t.player(r.opponent)
          rsig.concat(o.first_name[0])
          rsig.concat(o.last_name[0])
        end
        sig << rsig
      end
      sig.join('|')
    end

    before(:each) do
      @t = test_tournament("bunratty_masters_2011.tab", 1)
      @icut = @t.icu_tournament(renumber: :rank)
    end

    it "should create an ICU::Tournament copy" do
      @icut.should be_an_instance_of(ICU::Tournament)
      @icut.name.should == @t.name
      @icut.start.should == @t.start.to_s
      @icut.finish.should == (@t.finish ? @t.finish.to_s : nil)
      %w[rounds fed city site arbiter deputy time_control].each do |attr|
        @icut.send(attr).should == @t.send(attr)
      end
      @icut.players.size.should == @t.players.size
      player_signature(@icut, 35).should == '35|35|David|Murray|||M|||4941|||1LBrMP|2DWrLP|6Lu'
      player_signature(@icut,  6).should == '6|6|Nigel|Short|ENG|GM|M||2658|||1965-06-01|1WWrKM|2DBrAH|3WWrSC|4LBrGJ|5DWrDF|6WBrPS'
      player_signature(@icut, 30).should == '30|30|Alexandra|Wilson||WCM|F|||7938|||1LBrMH|2LWrRW|3DBrSD|4LWrJC|5DBrRM|6WWrKO'
    end
  end

  context "#tie_break_selections" do
    before(:each) do
      @t = Tournament.new(name: 'Test', start: "2000-01-01")
    end

    it "should create an ordered array of a tie break rule paired with a true or false value" do
      @t.tie_breaks = 'buchholz,modified_median'
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == "BH|MM|HK|NB|NW|PN|SB|SR|SP"
      @t.tie_break_selections.map(&:last).join('_').should match(/^true_true(_false){7}$/)
    end

    it "should ignore invalid tie break identifiers" do
      @t.tie_breaks = 'invalid,harkness'
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == "HK|BH|MM|NB|NW|PN|SB|SR|SP"
      @t.tie_break_selections.map(&:last).join('_').should match(/^true(_false){8}$/)
    end

    it "second of the pairs should be false if there are no tie breaks" do
      @t.tie_breaks = nil
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == "BH|HK|MM|NB|NW|PN|SB|SR|SP"
      @t.tie_break_selections.map(&:last).join('_').should match(/^false(_false){8}$/)
    end
  end

  context "#rate!" do
    it "should rate tournaments" do
      # Setup two tournaments to begin with.
      @p = load_icu_players
      @r = load_old_ratings
      @u = FactoryGirl.create(:user, role: "officer")
      @t1, @t3 = %w{bunratty_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t
      end

      # What tournament should be rated next?
      Tournament.next_for_rating.should == @t1

      # Pre-rating 1st tournament data.
      @t1.reratings.should == 0
      @t1.first_rated.should be_nil
      @t1.last_rated.should be_nil
      @t1.stage.should == "queued"
      @t1.rorder.should == 1
      @t1.last_signature.should be_nil
      @t1.curr_signature.should be_nil
      @t1.locked.should be_false

      # Rate the 1st tournament.
      @t1.rate!

      # ICU player with full rating.
      p = @t1.players.find_by_last_name("Cafolla")
      p.category.should == "icu_player"
      p.icu_id.should == 159
      p.old_rating.should == 1982
      p.old_games.should == 1111
      p.old_full.should be_true
      p.last_player_id.should be_nil
      p.k_factor.should == 24
      p.actual_score.should == 2.5
      p.unrateable.should be_false
      p.new_rating.should be_within(1).of(2000)
      p.trn_rating.should be_within(1).of(2156)
      p.new_games.should == 1116
      p.new_full.should be_true
      p.bonus.should == 0
      p.expected_score.should be_within(0.0001).of(1.7660)
      p.last_signature.should == "159 1L11 2D19 3W27 4W25 5L7"
      p.curr_signature.should == p.last_signature

      # ICU player with full rating but started with less than 20 games.
      p = @t1.players.find_by_last_name("O'Riordan")
      p.category.should == "icu_player"
      p.icu_id.should == 10235
      p.old_rating.should == 1881
      p.old_games.should == 12
      p.old_full.should be_true
      p.last_player_id.should be_nil
      p.k_factor.should == 40
      p.actual_score.should == 1.5
      p.unrateable.should be_false
      p.new_rating.should be_within(1).of(1871)
      p.trn_rating.should be_within(1).of(1842)
      p.new_games.should == 18
      p.new_full.should be_true
      p.bonus.should == 0
      p.expected_score.should be_within(0.0001).of(1.7566)
      p.last_signature.should == "10235 1D24 2D20 3L19 4L21 5D29 6L30"
      p.curr_signature.should == p.last_signature

      # ICU player with provisional rating.
      p = @t1.players.find_by_last_name("Maroroa")
      p.category.should == "icu_player"
      p.icu_id.should == 8453
      p.old_rating.should == 2031
      p.old_games.should be < 20
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == 3.5
      p.unrateable.should be_false
      p.new_rating.should be_within(1).of(2039)
      p.trn_rating.should be_within(1).of(2039)
      p.new_games.should == p.old_games + 6
      p.new_full.should be_true
      p.bonus.should be_nil
      p.expected_score.should be_within(0.0001).of(3.3911)
      p.last_signature.should == "8453 1L5 2L23 3W33 4D17 5W26 6W24"
      p.curr_signature.should == p.last_signature

      # ICU player with no previous rating.
      p = @t1.players.find_by_last_name("Daianu")
      p.category.should == "icu_player"
      p.icu_id.should == 12376
      p.old_rating.should be_nil
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == 3.0
      p.unrateable.should be_false
      p.new_rating.should be_within(1).of(2203)
      p.trn_rating.should be_within(1).of(2203)
      p.new_games.should == 6
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_within(0.0001).of(2.9319)
      p.last_signature.should == "12376 1W31 2D1 3L11 4D10 5W22 6L5"
      p.curr_signature.should == p.last_signature

      # New player, no ICU number.
      p = @t1.players.find_by_last_name("Fehr")
      p.category.should == "new_player"
      p.icu_id.should be_nil
      p.old_rating.should be_nil
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == 1.5
      p.unrateable.should be_false
      p.new_rating.should be_within(1).of(1776)
      p.trn_rating.should be_within(1).of(1776)
      p.new_games.should == 6
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_within(0.0001).of(1.6341)
      p.last_signature.should == "1L16 2D10 3L26 4D29 5L17 6D33"
      p.curr_signature.should == p.last_signature

      # Foreign guest.
      p = @t1.players.find_by_last_name_and_first_name("Short", "Nigel")
      p.category.should == "foreign_player"
      p.icu_id.should be_nil
      p.old_rating.should == p.fide_rating
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == 4.0
      p.unrateable.should be_false
      p.new_rating.should == p.fide_rating
      p.trn_rating.should be_within(1).of(2464)
      p.new_games.should == 0
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_within(0.0001).of(5.0379)
      p.last_signature.should == "2658 1W19 2D11 3W8 4L1 5D9 6W14"
      p.curr_signature.should == p.last_signature

      # ICU player who played no rated games in this tournament.
      p = @t1.players.find_by_last_name("Orr")
      p.category.should == "icu_player"
      p.icu_id.should == 1350
      p.old_rating.should == 2192
      p.old_games.should == 329
      p.old_full.should be_true
      p.last_player_id.should be_nil
      p.k_factor.should == 16
      p.actual_score.should be_nil
      p.unrateable.should be_false
      p.new_rating.should == 2192
      p.trn_rating.should be_nil
      p.new_games.should == 329
      p.new_full.should be_true
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == "1350"
      p.curr_signature.should == p.last_signature

      # New player, no ICU number, no rated games in this tournament.
      p = @t1.players.find_by_last_name("Grennel")
      p.category.should == "new_player"
      p.icu_id.should be_nil
      p.old_rating.should be_nil
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should be_nil
      p.unrateable.should be_false
      p.new_rating.should be_nil
      p.trn_rating.should be_nil
      p.new_games.should == 0
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == ""
      p.curr_signature.should == p.last_signature

      # Foreign guest, no rated games in this tournament.
      p = @t1.players.find_by_last_name("Hebden")
      p.category.should == "foreign_player"
      p.icu_id.should be_nil
      p.old_rating.should == p.fide_rating
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == nil
      p.unrateable.should be_false
      p.new_rating.should == p.fide_rating
      p.trn_rating.should be_nil
      p.new_games.should == 0
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == "2550"
      p.curr_signature.should == p.last_signature

      # Unrateable ICU player with provisional rating.
      p = @t1.players.find_by_last_name("Graham")
      p.category.should == "icu_player"
      p.icu_id.should == 12664
      p.old_rating.should == 497
      p.old_games.should == 5
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == nil
      p.unrateable.should be_true
      p.new_rating.should == p.old_rating
      p.trn_rating.should be_nil
      p.new_games.should == p.old_games
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == "12664 1D36 2D37"
      p.curr_signature.should == p.last_signature

      # Unrateable ICU player with no previous rating.
      p = @t1.players.find_by_last_name("Mitchell")
      p.category.should == "icu_player"
      p.icu_id.should == 12833
      p.old_rating.should be_nil
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == nil
      p.unrateable.should be_true
      p.new_rating.should == p.old_rating
      p.trn_rating.should be_nil
      p.new_games.should == p.old_games
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == "12833 1D34"
      p.curr_signature.should == p.last_signature

      # Unrateable new player.
      p = @t1.players.find_by_last_name("Baczkowski")
      p.category.should == "new_player"
      p.icu_id.should be_nil
      p.old_rating.should be_nil
      p.old_games.should == 0
      p.old_full.should be_false
      p.last_player_id.should be_nil
      p.k_factor.should be_nil
      p.actual_score.should == nil
      p.unrateable.should be_true
      p.new_rating.should == p.old_rating
      p.trn_rating.should be_nil
      p.new_games.should == p.old_games
      p.new_full.should be_false
      p.bonus.should be_nil
      p.expected_score.should be_nil
      p.last_signature.should == "2D34"
      p.curr_signature.should == p.last_signature

      # The number of players who start without any rating.
      @t1.players.find_all{ |p| p.old_rating.nil? }.count.should == 5

      # K-factors.
      @t1.players.find_all{ |p| p.k_factor == 16 }.size.should == 18
      @t1.players.find_all{ |p| p.k_factor == 24 }.size.should == 8
      @t1.players.find_all{ |p| p.k_factor == 32 }.size.should == 1
      @t1.players.find_all{ |p| p.k_factor == 40 }.size.should == 4
      @t1.players.find_all{ |p| p.k_factor.nil?  }.size.should == 9

      # New tournament data.
      @t1.reratings.should == 1
      @t1.first_rated.should_not be_nil
      @t1.last_rated.should == @t1.first_rated
      @t1.stage.should == "rated"
      @t1.last_signature.should_not be_nil
      @t1.curr_signature.should == @t1.last_signature
      @t1.last_tournament_id.should == @t1.old_last_tournament_id
      @t1.locked.should be_true

      # What tournament should be rated next?
      Tournament.next_for_rating.should == @t3

      # Pre-rating 2nd tournament data.
      @t3.reratings.should == 0
      @t3.first_rated.should be_nil
      @t3.last_rated.should be_nil
      @t3.stage.should == "queued"
      @t3.rorder.should == 2

      # Rate the 2nd tournament.
      @t3.rate!

      # ICU player with full rating who played in both tournaments.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p3 = @t3.players.find_by_last_name("Cafolla")
      p3.old_rating.should == p1.new_rating
      p3.old_games.should == p1.new_games
      p3.old_full.should be_true
      p3.last_player_id.should == p1.id
      p3.k_factor.should == p1.k_factor
      p3.bonus.should == 0
      p3.unrateable.should be_false
      p3.new_rating.should be < p3.old_rating
      p3.new_games.should == p3.old_games + 6
      p3.new_full.should be_true
      ((p3.actual_score - p3.expected_score) * p3.k_factor).should be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with full rating but started with less than 20 games.
      p1 = @t1.players.find_by_last_name("O'Riordan")
      p3 = @t3.players.find_by_last_name("O'Riordan")
      p3.old_rating.should == p1.new_rating
      p3.old_games.should == p1.new_games
      p3.old_full.should be_true
      p3.last_player_id.should == p1.id
      p3.k_factor.should == p1.k_factor
      p3.bonus.should == 0
      p3.unrateable.should be_false
      p3.new_rating.should be < p3.old_rating
      p3.new_games.should == p3.old_games + 6
      p3.new_full.should be_true
      ((p3.actual_score - p3.expected_score) * p3.k_factor).should be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with full rating who only played in this tournament.
      p3 = @t3.players.find_by_last_name("Quinn")
      p3.old_rating.should == @r[1402].rating
      p3.old_games.should == @r[1402].games
      p3.old_full.should == @r[1402].full
      p3.last_player_id.should be_nil
      p3.bonus.should == 0
      p3.k_factor.should == 16
      p3.unrateable.should be_false
      p3.new_rating.should be > p3.old_rating
      p3.new_games.should == p3.old_games + 6
      p3.new_full.should be_true
      ((p3.actual_score - p3.expected_score) * p3.k_factor).should be_within(0.5).of(p3.new_rating - p3.old_rating)

      # Foreign guest, played in both tournaments.
      p1 = @t1.players.find_by_last_name("Hebden")
      p3 = @t3.players.find_by_last_name("Hebden")
      p3.category.should == "foreign_player"
      p3.unrateable.should be_false
      p3.old_rating.should_not == p1.new_rating
      p3.last_player_id.should be_nil

      # Played in both tournaments and transitioned from provisional to full rating.
      p1 = @t1.players.find_by_last_name("Maroroa")
      p3 = @t3.players.find_by_last_name("Maroroa")
      p3.category.should == "icu_player"
      p3.old_rating.should == p1.new_rating
      p3.old_games.should == p1.new_games
      p1.old_games.should be < 20
      p3.old_games.should be >= 20
      p1.old_full.should be_false
      p3.old_full.should be_true
      p3.last_player_id.should == p1.id
      p3.k_factor.should_not be_nil
      p3.unrateable.should be_false
      p3.new_games.should == p3.old_games + 6
      p3.new_full.should be_true
      p3.bonus.should == 0
      ((p3.actual_score - p3.expected_score) * p3.k_factor).should be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with provisional rating who was unrateable in his last tournament.
      p1 = @t1.players.find_by_last_name("Graham")
      p3 = @t3.players.find_by_last_name("Graham")
      p3.category.should == "icu_player"
      p3.old_rating.should == p1.new_rating
      p3.old_games.should == p1.new_games
      p3.old_full.should == p1.new_full
      p3.last_player_id.should == p1.id
      p3.k_factor.should be_nil
      p3.actual_score.should == 1.0
      p3.unrateable.should be_false
      p3.new_rating.should_not == p1.new_rating
      p3.trn_rating.should_not be_nil
      p3.new_games.should == p1.new_games + 2
      p3.new_full.should be_false
      p3.bonus.should be_nil
      p3.expected_score.should_not be_nil

      # ICU player with no previous rating who was unrateable in his last tournament.
      p1 = @t1.players.find_by_last_name("Mitchell")
      p3 = @t3.players.find_by_last_name("Mitchell")
      p3.category.should == "icu_player"
      p3.old_rating.should be_nil
      p3.old_games.should == 0
      p3.old_full.should be_false
      p3.last_player_id.should == p1.id
      p3.k_factor.should be_nil
      p3.actual_score.should == 0.5
      p3.unrateable.should be_false
      p3.new_rating.should_not be_nil
      p3.trn_rating.should_not be_nil
      p3.new_games.should == 1
      p3.new_full.should be_false
      p3.bonus.should be_nil
      p3.expected_score.should_not be_nil

      # Check new tournament data.
      @t3.reratings.should == 1
      @t3.first_rated.should_not be_nil
      @t3.last_rated.should == @t3.first_rated
      @t3.stage.should == "rated"
      @t3.last_tournament_id.should == @t3.old_last_tournament_id

      # What tournament should be rated next?
      Tournament.next_for_rating.should be_nil

      # Add a new tournament and reload the others (which will have been requeued).
      @t2 = test_tournament("kilbunny_masters_2011.tab", @u.id)
      @t2.move_stage("ready", @u)
      @t2.move_stage("queued", @u)
      [@t1, @t3].each { |t| t.reload }

      # The order now.
      @t1.rorder.should == 1
      @t2.rorder.should == 2
      @t3.rorder.should == 3

      # What tournament should be rated next?
      Tournament.next_for_rating.should == @t2

      # Rate it.
      @t2.rate!

      # What tournament should be rated next?
      Tournament.next_for_rating.should == @t3

      # Rate it.
      @t3.rate!

      # What tournament should be rated next?
      Tournament.next_for_rating.should be_nil

      # Check some player data.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p2 = @t2.players.find_by_last_name("Cafolla")
      p3 = @t3.players.find_by_last_name("Cafolla")
      p1.last_player.should be_nil
      p2.last_player.should == p1
      p3.last_player.should == p2
      p2.old_rating.should == p1.new_rating
      p3.old_rating.should == p2.new_rating
      p2.new_rating.should be < p1.new_rating
      p1 = @t1.players.find_by_last_name("Orr")
      p2 = @t2.players.find_by_last_name("Orr")
      p3 = @t3.players.find_by_last_name("Orr")
      p1.last_player.should be_nil
      p2.last_player.should == p1
      p3.should be_nil
      p2.old_rating.should == p1.new_rating
      p2.new_rating.should be > p1.new_rating

      # Check some tournament data.
      @t1.reratings.should == 1
      @t2.reratings.should == 1
      @t3.reratings.should == 2
      @t1.last_rated.should == @t1.first_rated
      @t2.last_rated.should == @t2.first_rated
      @t3.last_rated.should be > @t3.first_rated

      # Test the effect of altering a result in one of the tournaments.
      ["Orr", "Cafolla"].each do |n|
        p = @t2.players.find_by_last_name(n)
        r = p.results.first
        r.result = "D"
        r.save
      end
      @t2.reload
      @t2.check_for_changes  # this is needed here to do what Tournament#show would normally do
      @t2.last_signature.should_not == @t2.curr_signature

      # What tournaments should be rated next?
      Tournament.next_for_rating.should == @t2
      @t2.rate!
      @t2.last_signature.should == @t2.curr_signature
      Tournament.next_for_rating.should == @t3
      @t3.rate!
      Tournament.next_for_rating.should be_nil

      # Check some player data.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p2 = @t2.players.find_by_last_name("Cafolla")
      p2.new_rating.should be > p1.new_rating
      p1 = @t1.players.find_by_last_name("Orr")
      p2 = @t2.players.find_by_last_name("Orr")
      p2.new_rating.should be < p1.new_rating

      # Check some tournament data.
      @t1.reratings.should == 1
      @t2.reratings.should == 2
      @t3.reratings.should == 3
      @t1.last_rated.should == @t1.first_rated
      @t2.last_rated.should be > @t2.first_rated
      @t3.last_rated.should be > @t3.first_rated

      # Remember the rating of a player who played in both the last two tournaments.
      r123 = @t3.players.find_by_last_name("Cafolla").new_rating

      # Test the effect of moving the date of a tournament.
      @t3.last_tournament_id.should == @t3.old_last_tournament_id
      @t3.start = @t2.start - 1.day
      @t3.finish = @t2.finish - 1.day
      @t3.save
      @t3.reload
      @t3.last_tournament_id.should_not == @t3.old_last_tournament_id

      # The other two tournaments should have changed.
      [@t1, @t2].each { |t| t.reload }
      @t1.rorder.should == 1
      @t2.rorder.should == 3
      @t3.rorder.should == 2

      # The tournament that moved back in time should be the next to be rated.
      Tournament.next_for_rating.should == @t3
      @t3.rate!
      @t3.last_signature.should == @t3.curr_signature
      Tournament.next_for_rating.should == @t2
      @t2.rate!
      @t2.last_signature.should == @t2.curr_signature
      Tournament.next_for_rating.should be_nil

      # Check some tournament data.
      @t1.reratings.should == 1
      @t2.reratings.should == 3
      @t3.reratings.should == 4

      # The player's rating should have changed because of the different order.
      @t2.players.find_by_last_name("Cafolla").new_rating.should_not == r123

      # Put the tournament's back in the right order.
      @t3.last_tournament_id.should == @t3.old_last_tournament_id
      @t3.start = @t2.start + 1.day
      @t3.finish = @t2.finish + 1.day
      @t3.save
      @t3.reload
      @t3.last_tournament_id.should_not == @t3.old_last_tournament_id
      [@t1, @t2].each { |t| t.reload }
      @t1.rorder.should == 1
      @t2.rorder.should == 2
      @t3.rorder.should == 3

      # The middle tournament should be the first to be rated.
      Tournament.next_for_rating.should == @t2
      @t2.rate!
      @t2.last_signature.should == @t2.curr_signature
      Tournament.next_for_rating.should == @t3
      @t3.rate!
      @t3.last_signature.should == @t3.curr_signature
      Tournament.next_for_rating.should be_nil

      # Check some tournament data.
      @t1.reratings.should == 1
      @t2.reratings.should == 4
      @t3.reratings.should == 5

      # The player's final rating should now be back to what it was.
      @t3.players.find_by_last_name("Cafolla").new_rating.should == r123

      # Test the effect of merely rerating the first tournament without changing anything else.
      @t1.rate!
      Tournament.next_for_rating.should == @t2
      @t2.rate!
      Tournament.next_for_rating.should == @t3
      @t3.rate!
      Tournament.next_for_rating.should be_nil
      @t1.reratings.should == 2
      @t2.reratings.should == 5
      @t3.reratings.should == 6
    end
  end

  context "automatic requeuing" do
    before(:each) do
      load_icu_players
      u = FactoryGirl.create(:user, role: "officer")
      @t1, @t2, @t3 = %w{bunratty_masters_2011.tab kilbunny_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, u.id)
        t.move_stage("ready", u)
        t.move_stage("queued", u)
        t
      end
      [@t1, @t2, @t3].each { |t| t.reload }
    end

    it "should have correct initial ordering" do
      @t1.rorder.should == 1
      @t2.rorder.should == 2
      @t3.rorder.should == 3
      @t1.last_tournament.should be_nil
      @t2.last_tournament.should == @t1
      @t3.last_tournament.should == @t2
      @t1.next_tournament.should == @t2
      @t2.next_tournament.should == @t3
      @t3.next_tournament.should be_nil
    end

    it "should requeue a tournament that has changed significantly" do
      @t2.start = "2010-06-16"
      @t2.finish = "2010-06-18"
      @t2.save
      [@t1, @t2, @t3].each { |t| t.reload }
      @t1.rorder.should == 2
      @t2.rorder.should == 1
      @t3.rorder.should == 3
      @t2.start = "2012-01-16"
      @t2.finish = "2012-01-18"
      @t2.save
      [@t1, @t2, @t3].each { |t| t.reload }
      @t1.rorder.should == 1
      @t2.rorder.should == 3
      @t3.rorder.should == 2
    end

    it "finish is more significant than start" do
      @t1.finish = "2012-04-17"
      @t1.save
      [@t1, @t2, @t3].each { |t| t.reload }
      @t1.rorder.should == 3
      @t2.rorder.should == 1
      @t3.rorder.should == 2
      @t1.last_tournament.should == @t3
      @t2.last_tournament.should be_nil
      @t3.last_tournament.should == @t2
      @t1.next_tournament.should be_nil
      @t2.next_tournament.should == @t3
      @t3.next_tournament.should == @t1
    end
  end

  context "players signature" do
    before(:each) do
      f = "junior_championships_u19_2010.tab"
      load_icu_players_for(f)
      load_old_ratings
      @u = FactoryGirl.create(:user, role: "officer")
      @t = test_tournament(f, @u.id)
      @t.move_stage("ready", @u)
      @t.move_stage("queued", @u)
    end

    it "players signature is not changed by moving a tournament" do
      @t.move_stage("ready", @u)
      @t.check_for_changes
      @t.curr_signature.should be_nil
    end

    it "players signature differ after a rated tournament is changed" do
      @t.rate!
      @t.last_signature.should_not be_nil
      @t.curr_signature.should == @t.last_signature
      @t.players[0].results[1].result = 'D'
      @t.players[1].results[1].result = 'D'
      @t.check_for_changes
      @t.curr_signature.should_not == @t.last_signature
    end
  end

  context "unrateable tournaments" do
    before(:each) do
      f = "bunratty_masters_2011.tab"
      load_icu_players_for(f)
      load_old_ratings
      @u = FactoryGirl.create(:user, role: "officer")
      @t = test_tournament(f, @u.id)
      @t.move_stage("ready", @u)
      @t.move_stage("queued", @u)
    end

    it "should fail if wrong stage" do
      @t.move_stage("ready", @u)
      lambda{ @t.rate! }.should raise_error(/stage.*ready/)
    end

    it "should fail if there are any player issues" do
      p = @t.players.find_by_last_name("Cafolla")
      p.icu_id = p.icu_id + 1
      p.save
      @t.reload
      lambda{ @t.rate! }.should raise_error(/bad status/)
    end

    it "should not alter database if calculation fails" do
      @t.reratings.should == 0
      @t.stage.should == "queued"
      p = @t.players.find_by_last_name("Cafolla")
      p.old_rating.should be_nil
      @t.should_receive(:update_tournament_after_rating).and_raise(RuntimeError.new("oops"))
      lambda{ @t.rate! }.should raise_error(/oops/)
      @t.reload
      @t.reratings.should == 0
      @t.stage.should == "queued"
      p = @t.players.find_by_last_name("Cafolla")
      p.old_rating.should be_nil
    end
  end
end
