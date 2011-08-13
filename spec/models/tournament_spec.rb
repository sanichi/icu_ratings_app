require 'spec_helper'

describe Tournament do
  context "#icu_tournament" do
    def player_signature(t, n)
      p = t.player(n)
      sig = Array.new
      %w{num rank first_name last_name fed title gender rating fide_rating id fide_id dob}.each { |attr| sig << p.send(attr) }
      p.results.each do |r|
        rsig = %w{round score colour}.map { |attr| r.send(attr) }.join('')
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
      @t = test_tournament("bunratty_masters_2011.tab", :fide => true, :user_id => 1)
      @icut = @t.icu_tournament(:renumber => :rank)
    end

    it "should create an ICU::Tournament copy" do
      @icut.should be_an_instance_of(ICU::Tournament)
      @icut.name.should == @t.name
      @icut.start.should == @t.start.to_s
      @icut.finish.should == (@t.finish ? @t.finish.to_s : nil)
      %w{rounds fed city site arbiter deputy time_control}.each do |attr|
        @icut.send(attr).should == @t.send(attr)
      end
      @icut.players.size.should == @t.players.size
      player_signature(@icut, 34).should == '34|34|David|Murray|||M||2023|972|||1LBrMP|2DWrLP|6Lu'
      player_signature(@icut,  5).should == '5|5|Nigel|Short|ENG|GM|M||2658||400025|1965-06-01|1WWrKM|2DBrAH|3WWrSC|4LBrGJ|5DWrDF|6WBrPS'
      player_signature(@icut, 29).should == '29|29|Alexandra|Wilson|ENG|WFM|F||2020||||1LBrMH|2LWrRW|3DBrSD|4LWrJC|5DBrRM|6WWrKO'
    end
  end

  context "#tie_break_selections" do
    before(:each) do
      @t = Tournament.new(:name => 'Test', :start => "2000-01-01")
    end

    it "should create an ordered array of a tie break rule paired with a true or false value" do
      @t.tie_breaks = 'buchholz,modified_median'
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == 'BH|MM|HK|NB|NW|PN|SB|SR|SP'
      @t.tie_break_selections.map(&:last).join('_').should match(/^true_true(_false){7}$/)
    end

    it "should ignore invalid tie break identifiers" do
      @t.tie_breaks = 'invalid,harkness'
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == 'HK|BH|MM|NB|NW|PN|SB|SR|SP'
      @t.tie_break_selections.map(&:last).join('_').should match(/^true(_false){8}$/)
    end

    it "second of the pairs should be false if there are no tie breaks" do
      @t.tie_breaks = nil
      @t.tie_break_selections.map(&:first).map(&:code).join('|').should == 'BH|HK|MM|NB|NW|PN|SB|SR|SP'
      @t.tie_break_selections.map(&:last).join('_').should match(/^false(_false){8}$/)
    end
  end
end
