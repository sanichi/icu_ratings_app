require 'rails_helper'

describe Tournament do
  before(:all) do
    # Try to avoid the tendancy of before(:each) (in each group that needs it) to get an
    # ActiveRecord::RecordNotUnique error when all tests are run (but not just this file).
    @u = FactoryGirl.create(:user, role: "officer")
  end

  context "#name_with_year" do
    it "should add years to end of name" do
      t = Tournament.new
      t.name = "Masters"
      t.start = "2012-05-12"
      expect(t.name_with_year).to eq("Masters 2012")
      t.finish = "2012-05-13"
      expect(t.name_with_year).to eq("Masters 2012")
      t.finish = "2013-05-13"
      expect(t.name_with_year).to eq("Masters 2012-13")
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
      expect(@icut).to be_an_instance_of(ICU::Tournament)
      expect(@icut.name).to eq(@t.name)
      expect(@icut.start).to eq(@t.start.to_s)
      expect(@icut.finish).to eq(@t.finish ? @t.finish.to_s : nil)
      %w[rounds fed city site arbiter deputy time_control].each do |attr|
        expect(@icut.send(attr)).to eq(@t.send(attr))
      end
      expect(@icut.players.size).to eq(@t.players.size)
      expect(player_signature(@icut, 35)).to eq('35|35|David|Murray|||M|||4941|||1LBrMP|2DWrLP|6Lu')
      expect(player_signature(@icut,  6)).to eq('6|6|Nigel|Short|ENG|GM|M||2658|||1965-06-01|1WWrKM|2DBrAH|3WWrSC|4LBrGJ|5DWrDF|6WBrPS')
      expect(player_signature(@icut, 30)).to eq('30|30|Alexandra|Wilson||WCM|F|||7938|||1LBrMH|2LWrRW|3DBrSD|4LWrJC|5DBrRM|6WWrKO')
    end
  end

  context "#tie_break_selections" do
    before(:each) do
      @t = Tournament.new(name: 'Test', start: "2000-01-01")
    end

    it "should create an ordered array of a tie break rule paired with a true or false value" do
      @t.tie_breaks = 'buchholz,modified_median'
      expect(@t.tie_break_selections.map(&:first).map(&:code).join('|')).to eq("BH|MM|HK|NB|NW|PN|SB|SR|SP")
      expect(@t.tie_break_selections.map(&:last).join('_')).to match(/^true_true(_false){7}$/)
    end

    it "should ignore invalid tie break identifiers" do
      @t.tie_breaks = 'invalid,harkness'
      expect(@t.tie_break_selections.map(&:first).map(&:code).join('|')).to eq("HK|BH|MM|NB|NW|PN|SB|SR|SP")
      expect(@t.tie_break_selections.map(&:last).join('_')).to match(/^true(_false){8}$/)
    end

    it "second of the pairs should be false if there are no tie breaks" do
      @t.tie_breaks = nil
      expect(@t.tie_break_selections.map(&:first).map(&:code).join('|')).to eq("BH|HK|MM|NB|NW|PN|SB|SR|SP")
      expect(@t.tie_break_selections.map(&:last).join('_')).to match(/^false(_false){8}$/)
    end
  end

  context "#rate!" do
    it "should rate tournaments" do
      # Setup two tournaments to begin with.
      @p = load_icu_players
      @r = load_old_ratings
      @t1, @t3 = %w{bunratty_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t
      end

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to eq(@t1)

      # Pre-rating 1st tournament data.
      expect(@t1.reratings).to eq(0)
      expect(@t1.first_rated).to be_nil
      expect(@t1.last_rated).to be_nil
      expect(@t1.stage).to eq("queued")
      expect(@t1.rorder).to eq(1)
      expect(@t1.last_signature).to be_nil
      expect(@t1.curr_signature).to be_nil
      expect(@t1.locked).to be false

      # Rate the 1st tournament.
      @t1.rate!

      # ICU player with full rating.
      p = @t1.players.find_by_last_name("Cafolla")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(159)
      expect(p.old_rating).to eq(1982)
      expect(p.old_games).to eq(1111)
      expect(p.old_full).to be true
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to eq(24)
      expect(p.actual_score).to eq(2.5)
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_within(1).of(2000)
      expect(p.trn_rating).to be_within(1).of(2156)
      expect(p.new_games).to eq(1116)
      expect(p.new_full).to be true
      expect(p.rating_change).to be_within(1).of(18)
      expect(p.bonus).to eq(0)
      expect(p.expected_score).to be_within(0.0001).of(1.7660)
      expect(p.last_signature).to eq("159 1L11 2D19 3W27 4W25 5L7")
      expect(p.curr_signature).to eq(p.last_signature)

      # ICU player with full rating but started with less than 20 games.
      p = @t1.players.find_by_last_name("O'Riordan")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(10235)
      expect(p.old_rating).to eq(1881)
      expect(p.old_games).to eq(12)
      expect(p.old_full).to be true
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to eq(40)
      expect(p.actual_score).to eq(1.5)
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_within(1).of(1871)
      expect(p.trn_rating).to be_within(1).of(1842)
      expect(p.new_games).to eq(18)
      expect(p.new_full).to be true
      expect(p.rating_change).to be_within(1).of(-10)
      expect(p.bonus).to eq(0)
      expect(p.expected_score).to be_within(0.0001).of(1.7566)
      expect(p.last_signature).to eq("10235 1D24 2D20 3L19 4L21 5D29 6L30")
      expect(p.curr_signature).to eq(p.last_signature)

      # ICU player with provisional rating.
      p = @t1.players.find_by_last_name("Maroroa")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(8453)
      expect(p.old_rating).to eq(2031)
      expect(p.old_games).to be < 20
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(3.5)
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_within(1).of(2039)
      expect(p.trn_rating).to be_within(1).of(2039)
      expect(p.new_games).to eq(p.old_games + 6)
      expect(p.new_full).to be true
      expect(p.rating_change).to be_within(1).of(8)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_within(0.0001).of(3.3911)
      expect(p.last_signature).to eq("8453 1L5 2L23 3W33 4D17 5W26 6W24")
      expect(p.curr_signature).to eq(p.last_signature)

      # ICU player with no previous rating.
      p = @t1.players.find_by_last_name("Daianu")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(12376)
      expect(p.old_rating).to be_nil
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(3.0)
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_within(1).of(2203)
      expect(p.trn_rating).to be_within(1).of(2203)
      expect(p.new_games).to eq(6)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_within(0.0001).of(2.9321)
      expect(p.last_signature).to eq("12376 1W31 2D1 3L11 4D10 5W22 6L5")
      expect(p.curr_signature).to eq(p.last_signature)

      # New player, no ICU number.
      p = @t1.players.find_by_last_name("Fehr")
      expect(p.category).to eq("new_player")
      expect(p.icu_id).to be_nil
      expect(p.old_rating).to be_nil
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(1.5)
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_within(1).of(1776)
      expect(p.trn_rating).to be_within(1).of(1776)
      expect(p.new_games).to eq(6)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_within(0.0001).of(1.6339)
      expect(p.last_signature).to eq("1L16 2D10 3L26 4D29 5L17 6D33")
      expect(p.curr_signature).to eq(p.last_signature)

      # Foreign guest.
      p = @t1.players.find_by_last_name_and_first_name("Short", "Nigel")
      expect(p.category).to eq("foreign_player")
      expect(p.icu_id).to be_nil
      expect(p.old_rating).to eq(p.fide_rating)
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(4.0)
      expect(p.unrateable).to be false
      expect(p.new_rating).to eq(p.fide_rating)
      expect(p.trn_rating).to be_within(1).of(2464)
      expect(p.new_games).to eq(0)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_within(0.0001).of(5.0379)
      expect(p.last_signature).to eq("2658 1W19 2D11 3W8 4L1 5D9 6W14")
      expect(p.curr_signature).to eq(p.last_signature)

      # ICU player who played no rated games in this tournament.
      p = @t1.players.find_by_last_name("Orr")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(1350)
      expect(p.old_rating).to eq(2192)
      expect(p.old_games).to eq(329)
      expect(p.old_full).to be true
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to eq(16)
      expect(p.actual_score).to be_nil
      expect(p.unrateable).to be false
      expect(p.new_rating).to eq(2192)
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(329)
      expect(p.new_full).to be true
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("1350")
      expect(p.curr_signature).to eq(p.last_signature)

      # New player, no ICU number, no rated games in this tournament.
      p = @t1.players.find_by_last_name("Grennel")
      expect(p.category).to eq("new_player")
      expect(p.icu_id).to be_nil
      expect(p.old_rating).to be_nil
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to be_nil
      expect(p.unrateable).to be false
      expect(p.new_rating).to be_nil
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(0)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("")
      expect(p.curr_signature).to eq(p.last_signature)

      # Foreign guest, no rated games in this tournament.
      p = @t1.players.find_by_last_name("Hebden")
      expect(p.category).to eq("foreign_player")
      expect(p.icu_id).to be_nil
      expect(p.old_rating).to eq(p.fide_rating)
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(nil)
      expect(p.unrateable).to be false
      expect(p.new_rating).to eq(p.fide_rating)
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(0)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("2550")
      expect(p.curr_signature).to eq(p.last_signature)

      # Unrateable ICU player with provisional rating.
      p = @t1.players.find_by_last_name("Graham")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(12664)
      expect(p.old_rating).to eq(497)
      expect(p.old_games).to eq(5)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(nil)
      expect(p.unrateable).to be true
      expect(p.new_rating).to eq(p.old_rating)
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(p.old_games)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("12664 1D36 2D37")
      expect(p.curr_signature).to eq(p.last_signature)

      # Unrateable ICU player with no previous rating.
      p = @t1.players.find_by_last_name("Mitchell")
      expect(p.category).to eq("icu_player")
      expect(p.icu_id).to eq(12833)
      expect(p.old_rating).to be_nil
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(nil)
      expect(p.unrateable).to be true
      expect(p.new_rating).to eq(p.old_rating)
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(p.old_games)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("12833 1D34")
      expect(p.curr_signature).to eq(p.last_signature)

      # Unrateable new player.
      p = @t1.players.find_by_last_name("Baczkowski")
      expect(p.category).to eq("new_player")
      expect(p.icu_id).to be_nil
      expect(p.old_rating).to be_nil
      expect(p.old_games).to eq(0)
      expect(p.old_full).to be false
      expect(p.last_player_id).to be_nil
      expect(p.k_factor).to be_nil
      expect(p.actual_score).to eq(nil)
      expect(p.unrateable).to be true
      expect(p.new_rating).to eq(p.old_rating)
      expect(p.trn_rating).to be_nil
      expect(p.new_games).to eq(p.old_games)
      expect(p.new_full).to be false
      expect(p.rating_change).to eq(0)
      expect(p.bonus).to be_nil
      expect(p.expected_score).to be_nil
      expect(p.last_signature).to eq("2D34")
      expect(p.curr_signature).to eq(p.last_signature)

      # The number of players who start without any rating.
      expect(@t1.players.find_all{ |p| p.old_rating.nil? }.count).to eq(5)

      # K-factors.
      expect(@t1.players.find_all{ |p| p.k_factor == 16 }.size).to eq(18)
      expect(@t1.players.find_all{ |p| p.k_factor == 24 }.size).to eq(8)
      expect(@t1.players.find_all{ |p| p.k_factor == 32 }.size).to eq(1)
      expect(@t1.players.find_all{ |p| p.k_factor == 40 }.size).to eq(4)
      expect(@t1.players.find_all{ |p| p.k_factor.nil?  }.size).to eq(9)

      # New tournament data.
      expect(@t1.reratings).to eq(1)
      expect(@t1.first_rated).to_not be_nil
      expect(@t1.last_rated).to eq(@t1.first_rated)
      expect(@t1.stage).to eq("rated")
      expect(@t1.last_signature).to_not be_nil
      expect(@t1.curr_signature).to eq(@t1.last_signature)
      expect(@t1.last_tournament_id).to eq(@t1.old_last_tournament_id)
      expect(@t1.locked).to be true

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to eq(@t3)

      # Pre-rating 2nd tournament data.
      expect(@t3.reratings).to eq(0)
      expect(@t3.first_rated).to be_nil
      expect(@t3.last_rated).to be_nil
      expect(@t3.stage).to eq("queued")
      expect(@t3.rorder).to eq(2)

      # Rate the 2nd tournament.
      @t3.rate!

      # ICU player with full rating who played in both tournaments.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p3 = @t3.players.find_by_last_name("Cafolla")
      expect(p3.old_rating).to eq(p1.new_rating)
      expect(p3.old_games).to eq(p1.new_games)
      expect(p3.old_full).to be true
      expect(p3.last_player_id).to eq(p1.id)
      expect(p3.k_factor).to eq(p1.k_factor)
      expect(p3.bonus).to eq(0)
      expect(p3.unrateable).to be false
      expect(p3.new_rating).to be < p3.old_rating
      expect(p3.new_games).to eq(p3.old_games + 6)
      expect(p3.new_full).to be true
      expect(p3.rating_change).to eq(p3.new_rating - p3.old_rating)
      expect((p3.actual_score - p3.expected_score) * p3.k_factor).to be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with full rating but started with less than 20 games.
      p1 = @t1.players.find_by_last_name("O'Riordan")
      p3 = @t3.players.find_by_last_name("O'Riordan")
      expect(p3.old_rating).to eq(p1.new_rating)
      expect(p3.old_games).to eq(p1.new_games)
      expect(p3.old_full).to be true
      expect(p3.last_player_id).to eq(p1.id)
      expect(p3.k_factor).to eq(p1.k_factor)
      expect(p3.bonus).to eq(0)
      expect(p3.unrateable).to be false
      expect(p3.new_rating).to be < p3.old_rating
      expect(p3.new_games).to eq(p3.old_games + 6)
      expect(p3.new_full).to be true
      expect(p3.rating_change).to eq(p3.new_rating - p3.old_rating)
      expect((p3.actual_score - p3.expected_score) * p3.k_factor).to be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with full rating who only played in this tournament.
      p3 = @t3.players.find_by_last_name("Quinn")
      expect(p3.old_rating).to eq(@r[1402].rating)
      expect(p3.old_games).to eq(@r[1402].games)
      expect(p3.old_full).to eq(@r[1402].full)
      expect(p3.last_player_id).to be_nil
      expect(p3.bonus).to eq(0)
      expect(p3.k_factor).to eq(16)
      expect(p3.unrateable).to be false
      expect(p3.new_rating).to be > p3.old_rating
      expect(p3.new_games).to eq(p3.old_games + 6)
      expect(p3.new_full).to be true
      expect(p3.rating_change).to eq(p3.new_rating - p3.old_rating)
      expect((p3.actual_score - p3.expected_score) * p3.k_factor).to be_within(0.5).of(p3.new_rating - p3.old_rating)

      # Foreign guest, played in both tournaments.
      p1 = @t1.players.find_by_last_name("Hebden")
      p3 = @t3.players.find_by_last_name("Hebden")
      expect(p3.category).to eq("foreign_player")
      expect(p3.unrateable).to be false
      expect(p3.old_rating).to_not eq(p1.new_rating)
      expect(p3.rating_change).to eq(0)
      expect(p3.last_player_id).to be_nil

      # Played in both tournaments and transitioned from provisional to full rating.
      p1 = @t1.players.find_by_last_name("Maroroa")
      p3 = @t3.players.find_by_last_name("Maroroa")
      expect(p3.category).to eq("icu_player")
      expect(p3.old_rating).to eq(p1.new_rating)
      expect(p3.old_games).to eq(p1.new_games)
      expect(p1.old_games).to be < 20
      expect(p3.old_games).to be >= 20
      expect(p1.old_full).to be false
      expect(p3.old_full).to be true
      expect(p3.last_player_id).to eq(p1.id)
      expect(p3.k_factor).to_not be_nil
      expect(p3.unrateable).to be false
      expect(p3.new_games).to eq(p3.old_games + 6)
      expect(p3.new_full).to be true
      expect(p3.rating_change).to eq(p3.new_rating - p3.old_rating)
      expect(p3.bonus).to eq(0)
      expect((p3.actual_score - p3.expected_score) * p3.k_factor).to be_within(0.5).of(p3.new_rating - p3.old_rating)

      # ICU player with provisional rating who was unrateable in his last tournament.
      p1 = @t1.players.find_by_last_name("Graham")
      p3 = @t3.players.find_by_last_name("Graham")
      expect(p3.category).to eq("icu_player")
      expect(p3.old_rating).to eq(p1.new_rating)
      expect(p3.old_games).to eq(p1.new_games)
      expect(p3.old_full).to eq(p1.new_full)
      expect(p3.last_player_id).to eq(p1.id)
      expect(p3.k_factor).to be_nil
      expect(p3.actual_score).to eq(1.0)
      expect(p3.unrateable).to be false
      expect(p3.new_rating).to_not eq(p1.new_rating)
      expect(p3.trn_rating).to_not be_nil
      expect(p3.new_games).to eq(p1.new_games + 2)
      expect(p3.new_full).to be false
      expect(p3.rating_change).to eq(p3.new_rating - p3.old_rating)
      expect(p3.bonus).to be_nil
      expect(p3.expected_score).to_not be_nil

      # ICU player with no previous rating who was unrateable in his last tournament.
      p1 = @t1.players.find_by_last_name("Mitchell")
      p3 = @t3.players.find_by_last_name("Mitchell")
      expect(p3.category).to eq("icu_player")
      expect(p3.old_rating).to be_nil
      expect(p3.old_games).to eq(0)
      expect(p3.old_full).to be false
      expect(p3.last_player_id).to eq(p1.id)
      expect(p3.k_factor).to be_nil
      expect(p3.actual_score).to eq(0.5)
      expect(p3.unrateable).to be false
      expect(p3.new_rating).to_not be_nil
      expect(p3.trn_rating).to_not be_nil
      expect(p3.new_games).to eq(1)
      expect(p3.new_full).to be false
      expect(p3.rating_change).to eq(0)
      expect(p3.bonus).to be_nil
      expect(p3.expected_score).to_not be_nil

      # Check new tournament data.
      expect(@t3.reratings).to eq(1)
      expect(@t3.first_rated).to_not be_nil
      expect(@t3.last_rated).to eq(@t3.first_rated)
      expect(@t3.stage).to eq("rated")
      expect(@t3.last_tournament_id).to eq(@t3.old_last_tournament_id)

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to be_nil

      # Add a new tournament and reload the others (which will have been requeued).
      @t2 = test_tournament("kilbunny_masters_2011.tab", @u.id)
      @t2.move_stage("ready", @u)
      @t2.move_stage("queued", @u)
      [@t1, @t3].each { |t| t.reload }

      # The order now.
      expect(@t1.rorder).to eq(1)
      expect(@t2.rorder).to eq(2)
      expect(@t3.rorder).to eq(3)

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to eq(@t2)

      # Rate it.
      @t2.rate!

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to eq(@t3)

      # Rate it.
      @t3.rate!

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to be_nil

      # Check some player data.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p2 = @t2.players.find_by_last_name("Cafolla")
      p3 = @t3.players.find_by_last_name("Cafolla")
      expect(p1.last_player).to be_nil
      expect(p2.last_player).to eq(p1)
      expect(p3.last_player).to eq(p2)
      expect(p2.old_rating).to eq(p1.new_rating)
      expect(p3.old_rating).to eq(p2.new_rating)
      expect(p2.new_rating).to be < p1.new_rating
      p1 = @t1.players.find_by_last_name("Orr")
      p2 = @t2.players.find_by_last_name("Orr")
      p3 = @t3.players.find_by_last_name("Orr")
      expect(p1.last_player).to be_nil
      expect(p2.last_player).to eq(p1)
      expect(p3).to be_nil
      expect(p2.old_rating).to eq(p1.new_rating)
      expect(p2.new_rating).to be > p1.new_rating

      # Check some tournament data.
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(1)
      expect(@t3.reratings).to eq(2)
      expect(@t1.last_rated).to eq(@t1.first_rated)
      expect(@t2.last_rated).to eq(@t2.first_rated)
      expect(@t3.last_rated).to be > @t3.first_rated

      # Test the effect of altering a result in one of the tournaments.
      ["Orr", "Cafolla"].each do |n|
        p = @t2.players.find_by_last_name(n)
        r = p.results.first
        r.result = "D"
        r.save
      end
      @t2.reload
      @t2.check_for_changes  # this is needed here to do what Tournament#show would normally do
      expect(@t2.last_signature).to_not eq(@t2.curr_signature)

      # What tournaments should be rated next?
      expect(Tournament.next_for_rating).to eq(@t2)
      @t2.rate!
      expect(@t2.last_signature).to eq(@t2.curr_signature)
      expect(Tournament.next_for_rating).to eq(@t3)
      @t3.rate!
      expect(Tournament.next_for_rating).to be_nil

      # Check some player data.
      p1 = @t1.players.find_by_last_name("Cafolla")
      p2 = @t2.players.find_by_last_name("Cafolla")
      expect(p2.new_rating).to be > p1.new_rating
      p1 = @t1.players.find_by_last_name("Orr")
      p2 = @t2.players.find_by_last_name("Orr")
      expect(p2.new_rating).to be < p1.new_rating

      # Check some tournament data.
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(2)
      expect(@t3.reratings).to eq(3)
      expect(@t1.last_rated).to eq(@t1.first_rated)
      expect(@t2.last_rated).to be > @t2.first_rated
      expect(@t3.last_rated).to be > @t3.first_rated

      # Remember the rating of a player who played in both the last two tournaments.
      r123 = @t3.players.find_by_last_name("Cafolla").new_rating

      # Test the effect of moving the date of a tournament.
      expect(@t3.last_tournament_id).to eq(@t3.old_last_tournament_id)
      @t3.start = @t2.start - 1.day
      @t3.finish = @t2.finish - 1.day
      @t3.save
      @t3.reload
      expect(@t3.last_tournament_id).to_not eq(@t3.old_last_tournament_id)

      # The other two tournaments should have changed.
      [@t1, @t2].each { |t| t.reload }
      expect(@t1.rorder).to eq(1)
      expect(@t2.rorder).to eq(3)
      expect(@t3.rorder).to eq(2)

      # The tournament that moved back in time should be the next to be rated.
      expect(Tournament.next_for_rating).to eq(@t3)
      @t3.rate!
      expect(@t3.last_signature).to eq(@t3.curr_signature)
      expect(Tournament.next_for_rating).to eq(@t2)
      @t2.rate!
      expect(@t2.last_signature).to eq(@t2.curr_signature)
      expect(Tournament.next_for_rating).to be_nil

      # Check some tournament data.
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(3)
      expect(@t3.reratings).to eq(4)

      # The player's rating should have changed because of the different order.
      expect(@t2.players.find_by_last_name("Cafolla").new_rating).to_not eq(r123)

      # Put the tournament's back in the right order.
      expect(@t3.last_tournament_id).to eq(@t3.old_last_tournament_id)
      @t3.start = @t2.start + 1.day
      @t3.finish = @t2.finish + 1.day
      @t3.save
      @t3.reload
      expect(@t3.last_tournament_id).to_not eq(@t3.old_last_tournament_id)
      [@t1, @t2].each { |t| t.reload }
      expect(@t1.rorder).to eq(1)
      expect(@t2.rorder).to eq(2)
      expect(@t3.rorder).to eq(3)

      # The middle tournament should be the first to be rated.
      expect(Tournament.next_for_rating).to eq(@t2)
      @t2.rate!
      expect(@t2.last_signature).to eq(@t2.curr_signature)
      expect(Tournament.next_for_rating).to eq(@t3)
      @t3.rate!
      expect(@t3.last_signature).to eq(@t3.curr_signature)
      expect(Tournament.next_for_rating).to be_nil

      # Check some tournament data.
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(4)
      expect(@t3.reratings).to eq(5)

      # The player's final rating should now be back to what it was.
      expect(@t3.players.find_by_last_name("Cafolla").new_rating).to eq(r123)

      # Test the effect of merely rerating the first tournament without changing anything else.
      @t1.rate!
      expect(Tournament.next_for_rating).to eq(@t2)
      @t2.rate!
      expect(Tournament.next_for_rating).to eq(@t3)
      @t3.rate!
      expect(Tournament.next_for_rating).to be_nil
      expect(@t1.reratings).to eq(2)
      expect(@t2.reratings).to eq(5)
      expect(@t3.reratings).to eq(6)
    end
  end

  context "rerate" do
    it "should allow tournaments to be rerated without any data changes" do
      # Setup two tournaments to begin with.
      @p = load_icu_players
      @r = load_old_ratings
      @t1, @t2 = %w{bunratty_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t
      end

      # What tournament should be rated next?
      expect(Tournament.next_for_rating).to eq(@t1)

      # Rate the 1st tournament.
      @t1.rate!

      # What tournament should be rated next now?
      expect(Tournament.next_for_rating).to eq(@t2)

      # Rate the 2nd tournament.
      @t2.rate!

      # What tournament should be rated next now?
      expect(Tournament.next_for_rating).to be_nil

      # Arrange for the second tournament to be rerated.
      @t2.rerate = true
      @t2.save
      expect(Tournament.next_for_rating).to eq(@t2)

      # Arrange for the second tournament to be rerated.
      @t1.rerate = true
      @t1.save
      expect(Tournament.next_for_rating).to eq(@t1)
    end
  end

  context "automatic requeuing" do
    before(:each) do
      load_icu_players
      #u = FactoryGirl.create(:user, role: "officer")
      @t1, @t2, @t3 = %w{bunratty_masters_2011.tab kilbunny_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t
      end
      [@t1, @t2, @t3].each { |t| t.reload }
    end

    it "should have correct initial ordering" do
      expect(@t1.rorder).to eq(1)
      expect(@t2.rorder).to eq(2)
      expect(@t3.rorder).to eq(3)
      expect(@t1.last_tournament).to be_nil
      expect(@t2.last_tournament).to eq(@t1)
      expect(@t3.last_tournament).to eq(@t2)
      expect(@t1.next_tournament).to eq(@t2)
      expect(@t2.next_tournament).to eq(@t3)
      expect(@t3.next_tournament).to be_nil
    end

    it "should requeue a tournament that has changed significantly" do
      @t2.start = "2010-06-16"
      @t2.finish = "2010-06-18"
      @t2.save
      [@t1, @t2, @t3].each { |t| t.reload }
      expect(@t1.rorder).to eq(2)
      expect(@t2.rorder).to eq(1)
      expect(@t3.rorder).to eq(3)
      @t2.start = "2012-01-16"
      @t2.finish = "2012-01-18"
      @t2.save
      [@t1, @t2, @t3].each { |t| t.reload }
      expect(@t1.rorder).to eq(1)
      expect(@t2.rorder).to eq(3)
      expect(@t3.rorder).to eq(2)
    end

    it "finish is more significant than start" do
      @t1.finish = "2012-04-17"
      @t1.save
      [@t1, @t2, @t3].each { |t| t.reload }
      expect(@t1.rorder).to eq(3)
      expect(@t2.rorder).to eq(1)
      expect(@t3.rorder).to eq(2)
      expect(@t1.last_tournament).to eq(@t3)
      expect(@t2.last_tournament).to be_nil
      expect(@t3.last_tournament).to eq(@t2)
      expect(@t1.next_tournament).to be_nil
      expect(@t2.next_tournament).to eq(@t3)
      expect(@t3.next_tournament).to eq(@t1)
    end
  end

  context "players signature" do
    before(:each) do
      f = "junior_championships_u19_2010.tab"
      load_icu_players_for(f)
      load_old_ratings
      @t = test_tournament(f, @u.id)
      @t.move_stage("ready", @u)
      @t.move_stage("queued", @u)
    end

    it "players signature is not changed by moving a tournament" do
      @t.move_stage("ready", @u)
      @t.check_for_changes
      expect(@t.curr_signature).to be_nil
    end

    it "players signature differs after a rated tournament is changed" do
      @t.rate!
      expect(@t.last_signature).to_not be_nil
      expect(@t.curr_signature).to eq(@t.last_signature)
      @t.players[0].results[1].result = 'D'
      @t.players[1].results[1].result = 'D'
      @t.check_for_changes
      expect(@t.curr_signature).to_not eq(@t.last_signature)
    end
  end

  context "unrateable tournaments" do
    before(:each) do
      f = "bunratty_masters_2011.tab"
      load_icu_players_for(f)
      load_old_ratings
      @t = test_tournament(f, @u.id)
      @t.move_stage("ready", @u)
      @t.move_stage("queued", @u)
    end

    it "should fail if wrong stage" do
      @t.move_stage("ready", @u)
      expect{ @t.rate! }.to raise_error(/stage.*ready/)
    end

    it "should fail if there are any player issues" do
      p = @t.players.find_by_last_name("Cafolla")
      p.icu_id = p.icu_id + 1
      p.save
      @t.reload
      expect{ @t.rate! }.to raise_error(/bad status/)
    end

    it "should not alter database if calculation fails" do
      expect(@t.reratings).to eq(0)
      expect(@t.stage).to eq("queued")
      p = @t.players.find_by_last_name("Cafolla")
      expect(p.old_rating).to be_nil
      expect(@t).to receive(:update_tournament_after_rating).and_raise(RuntimeError.new("oops"))
      expect{ @t.rate! }.to raise_error(/oops/)
      @t.reload
      expect(@t.reratings).to eq(0)
      expect(@t.stage).to eq("queued")
      p = @t.players.find_by_last_name("Cafolla")
      expect(p.old_rating).to be_nil
    end
  end

  context "update FIDE data" do
    before(:each) do
      f = "bunratty_masters_2011.tab"
      load_icu_players_for(f)
      load_fide_players
      @t = test_tournament(f, @u.id)
    end

    it "initial and updated status" do
      expect(@t.players.select{ |p| p.fide_id }.count).to eq(0)
      expect(@t.players.select{ |p| p.fed }.count).to eq(3)
      expect(@t.players.select{ |p| p.dob }.count).to eq(2)
      data = Tournaments::FideData.new(@t)
      expect(data.status.size).to be 3

      [
        ["FTT", 2, "Fehr|Short"],
        ["FTF", 1, "Hebden"],
        ["FFF", 37, "Baburin|Baczkowski|Cafolla|-|Wynarczyk"],
      ].each_with_index do |e, i|
        expect(data.status[i].sig).to eq(e[0])
        expect(data.status[i].count).to eq(e[1])
        expect(data.status[i].samples.map{ |p| p ? p.last_name : "-" }.join("|")).to eq(e[2])
      end

      data = Tournaments::FideData.new(@t, true)
      expect(data.status.size).to be 4
      [
        ["TTF", 21, "Baburin|Cafolla|Collins|-|Short"],
        ["FTT", 15, "Cooper|Daianu|Eliens|-|Wynarczyk"],
        ["FTF",  2, "Hebden|Maroroa"],
        ["FFF",  2, "Baczkowski|Grennel"],
      ].each_with_index do |e, i|
        expect(data.status[i].sig).to eq(e[0])
        expect(data.status[i].count).to eq(e[1])
        expect(data.status[i].samples.map{ |p| p ? p.last_name : "-" }.join("|")).to eq(e[2])
      end

      updates = data.updates
      expect(updates).to be_instance_of(Hash)
      expect(updates.count).to eq(16)
      expect(updates[:with_icu_id]).to eq(35)
      expect(updates[:fid_new].count).to eq(21)
      expect(updates[:fid_unchanged].count).to eq(0)
      expect(updates[:fid_changed].count).to eq(0)
      expect(updates[:fid_unrecognized].count).to eq(0)
      expect(updates[:fed_new].count).to eq(35)
      expect(updates[:fed_unchanged].count).to eq(0)
      expect(updates[:fed_changed].count).to eq(0)
      expect(updates[:fed_mismatch].count).to eq(0)
      expect(updates[:fed_unrecognized].count).to eq(0)
      expect(updates[:dob_new].count).to eq(13)
      expect(updates[:dob_unchanged].count).to eq(0)
      expect(updates[:dob_changed].count).to eq(0)
      expect(updates[:dob_mismatch].count).to eq(0)
      expect(updates[:dob_removed].count).to eq(0)
      expect(updates[:dob_unrecognized].count).to eq(0)
    end

    it "updated status corner cases" do
      [
        ["Baburin",  :fide_id,  2500914],  # correct ID
        ["Orr",      :fide_id,  2500000],  # incorrect ID
        ["Cafolla",  :fed,        "IRL"],  # correct fed
        ["Duffy",    :fed,        "ENG"],  # incorrect fed
        ["McMorrow", :dob, "1988-02-07"],  # correct DOB for player with FIDE ID
        ["Kosten",   :dob, "1958-07-24"],  # correct DOB for player without FIDE ID
        ["Williams", :dob, "1979-11-03"],  # incorrect DOB for player without FIDE ID
      ].each { |x| @t.players.find{ |p| p.last_name == x[0] }.update_column(x[1], x[2]) }

      IcuPlayer.find_by_last_name("Osborne").update_column(:fed, "ENG")   # artificially create a federation mismatch
      @t.players.find{ |p| p.last_name == "Osborne" }.icu_player.reload   # the icu_player needs reloaded
      FidePlayer.find_by_last_name("Freeman").update_column(:born, 1981)  # artificially create a DOB mismatch

      data = Tournaments::FideData.new(@t, true)
      expect(data.status.size).to be 5
      [
        ["TTF", 20, "Baburin|Cafolla|Collins|-|Short"],
        ["TFF",  1, "Osborne"],
        ["FTT", 15, "Cooper|Daianu|Eliens|-|Wynarczyk"],
        ["FTF",  2, "Hebden|Maroroa"],
        ["FFF",  2, "Baczkowski|Grennel"],
      ].each_with_index do |e, i|
        expect(data.status[i].sig).to eq(e[0])
        expect(data.status[i].count).to eq(e[1])
        expect(data.status[i].samples.map{ |p| p ? p.last_name : "-" }.join("|")).to eq(e[2])
      end

      updates = data.updates
      expect(updates).to be_instance_of(Hash)
      expect(updates.count).to eq(16)
      expect(updates[:with_icu_id]).to eq(35)
      expect(updates[:fid_new].count).to eq(19)
      expect(updates[:fid_unchanged].map(&:last_name).join("|")).to eq("Baburin")
      expect(updates[:fid_changed].map(&:last_name).join("|")).to eq("Orr")
      expect(updates[:fid_unrecognized].count).to eq(0)
      expect(updates[:fed_new].count).to eq(32)
      expect(updates[:fed_unchanged].map(&:last_name).join("|")).to eq("Cafolla")
      expect(updates[:fed_changed].map(&:last_name).join("|")).to eq("Duffy")
      expect(updates[:fed_mismatch].map(&:last_name).join("|")).to eq("Osborne")
      expect(updates[:fed_unrecognized].count).to eq(0)
      expect(updates[:dob_new].count).to eq(11)
      expect(updates[:dob_unchanged].count).to eq(0)
      expect(updates[:dob_changed].map(&:last_name).join("|")).to eq("Kosten|Williams")
      expect(updates[:dob_mismatch].map(&:last_name).join("|")).to eq("Freeman")
      expect(updates[:dob_removed].count).to eq(1)
      expect(updates[:dob_unrecognized].count).to eq(0)
    end
  end
end
