require 'spec_helper'

module IcuRatings
  describe Graph do
    it "initialize from user" do
      u = FactoryGirl.create(:user)
      g = Graph.new(u)
      g.title.should == u.icu_player.name
    end

    it "initialize from ICU player" do
      p = FactoryGirl.create(:icu_player)
      g = Graph.new(p)
      g.title.should == p.name
    end

    it "initialize from ICU rating" do
      r = FactoryGirl.create(:icu_rating)
      g = Graph.new(r)
      g.title.should == r.icu_player.name
      g.icu_ratings.size.should == 1
      g.icu_ratings[0].selected.should be true
    end

    it "initialize from FIDE player" do
      p = FactoryGirl.create(:fide_player)
      g = Graph.new(p)
      g.title.should == p.name
    end

    it "initialize from FIDE rating" do
      r = FactoryGirl.create(:fide_rating)
      g = Graph.new(r)
      g.title.should == r.fide_player.name
      g.fide_ratings.size.should == 1
      g.fide_ratings[0].selected.should be true
    end

    it "no player" do
      g = Graph.new(nil)
      g.available?.should be false
      g.title.should be_nil
    end

    it "no ratings" do
      p = FactoryGirl.create(:icu_player)
      g = Graph.new(p)
      g.available?.should be false
      g.icu_ratings.should be_empty
      g.fide_ratings.should be_empty
      range = g.rating_range
      range.first.should be < range.last
      range = g.list_range
      range.first.should be < range.last
    end

    it "one ICU rating" do
      r = FactoryGirl.create(:icu_rating, rating: 2192, list: "2011-09-01")
      g = Graph.new(r.icu_player)
      g.available?.should be true
      g.fide_ratings.should be_empty
      g.icu_ratings.should_not be_empty
      g.icu_ratings.size.should == 1
      g.icu_ratings.first.rating.should == 2192
      g.icu_ratings.first.list.should be_within(0.01).of(2011.69)
      g.icu_ratings.first.label.should == "2011 Sep"
      g.min_rating.should == 2192
      g.max_rating.should == 2192
      g.rating_range.first.should == 2100
      g.rating_range.last.should == 2200
      g.first_list.should be_within(0.01).of(2011.69)
      g.last_list.should be_within(0.01).of(2011.69)
      g.list_range.first.should == 2011
      g.list_range.last.should == 2012
    end

    it "one FIDE rating" do
      r = FactoryGirl.create(:fide_rating, rating: 2362, list: "2003-04-01")
      g = Graph.new(r.fide_player)
      g.available?.should be true
      g.icu_ratings.should be_empty
      g.fide_ratings.should_not be_empty
      g.fide_ratings.size.should == 1
      g.fide_ratings.first.rating.should == 2362
      g.fide_ratings.first.list.should be_within(0.01).of(2003.31)
      g.fide_ratings.first.label.should == "2003 Apr"
      g.min_rating.should == 2362
      g.max_rating.should == 2362
      g.rating_range.first.should == 2300
      g.rating_range.last.should == 2400
      g.first_list.should be_within(0.01).of(2003.31)
      g.last_list.should be_within(0.01).of(2003.31)
      g.list_range.first.should == 2003
      g.list_range.last.should == 2004
    end

    it "multiple ratings" do
      p = FactoryGirl.create(:icu_player)
      f = FactoryGirl.create(:fide_player, icu_player: p)
      FactoryGirl.create(:icu_rating, rating: 2312, list: "2003-01-01", icu_player: p)
      FactoryGirl.create(:icu_rating, rating: 2201, list: "2010-09-01", icu_player: p)
      FactoryGirl.create(:icu_rating, rating: 2192, list: "2011-09-01", icu_player: p)
      FactoryGirl.create(:fide_rating, rating: 2362, list: "2003-04-01", fide_player: f)
      FactoryGirl.create(:fide_rating, rating: 2260, list: "2011-11-01", fide_player: f)
      g = Graph.new(p)
      g.available?.should be true
      g.icu_ratings.size.should == 3
      g.fide_ratings.size.should == 2
      g.min_rating.should == 2192
      g.max_rating.should == 2362
      g.rating_range.first.should == 2100
      g.rating_range.last.should == 2400
      g.first_list.should be_within(0.01).of(2003.08)
      g.last_list.should be_within(0.01).of(2011.85)
      g.list_range.first.should == 2003
      g.list_range.last.should == 2012
    end
  end
end
