require 'spec_helper'

describe WAR do
  it "enough ratings for a 3 year average" do
    p1 = Factory(:icu_player)
    Factory(:icu_rating, rating: 2000, list: "2009-09-01", icu_player: p1)
    Factory(:icu_rating, rating: 2100, list: "2010-09-01", icu_player: p1)
    Factory(:icu_rating, rating: 2200, list: "2011-09-01", icu_player: p1)
    f1 = Factory(:fide_player, icu_player: p1)
    Factory(:fide_rating, rating: 2000, period: "2009-11-01", fide_player: f1)
    Factory(:fide_rating, rating: 2100, period: "2010-11-01", fide_player: f1)
    Factory(:fide_rating, rating: 2200, period: "2011-11-01", fide_player: f1)
    Factory(:fide_rating, rating: 2300, period: "2012-01-01", fide_player: f1)
    p2 = Factory(:icu_player, gender: "F")
    Factory(:icu_rating, rating: 1200, list: "2009-09-01", icu_player: p2)
    Factory(:icu_rating, rating: 1100, list: "2010-09-01", icu_player: p2)
    Factory(:icu_rating, rating: 1000, list: "2011-09-01", icu_player: p2)
    p3 = Factory(:icu_player)
    Factory(:icu_rating, rating: 1800, list: "2009-09-01", icu_player: p3, full: false)
    Factory(:icu_rating, rating: 1900, list: "2010-09-01", icu_player: p3)
    Factory(:icu_rating, rating: 2000, list: "2011-09-01", icu_player: p3)
    f3 = Factory(:fide_player, icu_player: p3)
    Factory(:fide_rating, rating: 2100, period: "2011-11-01", fide_player: f3)
    
    w = WAR.new(method: "war")
    
    w.available?.should be_true
    w.years.should == 3
    w.lists[:icu].map(&:to_s).join("|").should == "2009-09-01|2010-09-01|2011-09-01"
    w.lists[:fide].map(&:to_s).join("|").should == "2009-11-01|2010-11-01|2011-11-01"
    w.players.size.should == 2
    w.players.first.player.should == p1
    w.players.first.average.should be_within(0.01).of(2130.0)
    w.players.last.player.should == p3
    w.players.last.average.should be_within(0.01).of(2017.5)
    
    w = WAR.new(method: "war", gender: "F")
    
    w.available?.should be_true
    w.players.size.should == 1
    w.players.first.player.should == p2
    w.players.first.average.should be_within(0.01).of(1070.0)
    
    w = WAR.new(method: "simple")
    
    w.available?.should be_true
    w.years.should == 1
    w.lists[:icu].map(&:to_s).join("|").should == "2011-09-01"
    w.lists[:fide].map(&:to_s).join("|").should == "2011-11-01"
    w.players.size.should == 2
    w.players.first.average.should be_within(0.01).of(2200.0)
    w.players.last.average.should be_within(0.01).of(2050.0)
  end

  it "enough ratings for simple average" do
    p1 = Factory(:icu_player)
    Factory(:icu_rating, rating: 2200, list: "2011-09-01", icu_player: p1)
    f1 = Factory(:fide_player, icu_player: p1)
    Factory(:fide_rating, rating: 2200, period: "2011-11-01", fide_player: f1)
    Factory(:fide_rating, rating: 2300, period: "2012-01-01", fide_player: f1)
    p2 = Factory(:icu_player, gender: "F")
    Factory(:icu_rating, rating: 1000, list: "2011-09-01", icu_player: p2)
    p3 = Factory(:icu_player)
    Factory(:icu_rating, rating: 2000, list: "2011-09-01", icu_player: p3)
    f3 = Factory(:fide_player, icu_player: p3)
    Factory(:fide_rating, rating: 2100, period: "2011-11-01", fide_player: f3)
    
    w = WAR.new(method: "war")
    
    w.available?.should be_false
        
    w = WAR.new(method: "simple")
    
    w.available?.should be_true
    w.years.should == 1
    w.lists[:icu].map(&:to_s).join("|").should == "2011-09-01"
    w.lists[:fide].map(&:to_s).join("|").should == "2011-11-01"
    w.players.size.should == 2
    w.players.first.average.should be_within(0.01).of(2200.0)
    w.players.last.average.should be_within(0.01).of(2050.0)
        
    w = WAR.new(method: "simple", gender: "F")
    
    w.available?.should be_true
    w.players.size.should == 1
    w.players.first.average.should be_within(0.01).of(1000.0)
  end
  
  it "no data at all" do    
    WAR.new(method: "war").available?.should be_false
    WAR.new(method: "simple").available?.should be_false
  end
end
