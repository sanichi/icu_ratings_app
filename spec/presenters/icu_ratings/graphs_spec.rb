require 'spec_helper'

module IcuRatings
  describe Graph do
    it "initialize from user" do
      u = FactoryGirl.create(:user)
      g = Graph.new(u)
      expect(g.title).to eq(u.icu_player.name)
    end

    it "initialize from ICU player" do
      p = FactoryGirl.create(:icu_player)
      g = Graph.new(p)
      expect(g.title).to eq(p.name)
    end

    it "initialize from ICU rating" do
      r = FactoryGirl.create(:icu_rating)
      g = Graph.new(r)
      expect(g.title).to eq(r.icu_player.name)
      expect(g.icu_ratings.size).to eq(1)
      expect(g.icu_ratings[0].selected).to be true
    end

    it "initialize from FIDE player" do
      p = FactoryGirl.create(:fide_player)
      g = Graph.new(p)
      expect(g.title).to eq(p.name)
    end

    it "initialize from FIDE rating" do
      r = FactoryGirl.create(:fide_rating)
      g = Graph.new(r)
      expect(g.title).to eq(r.fide_player.name)
      expect(g.fide_ratings.size).to eq(1)
      expect(g.fide_ratings[0].selected).to be true
    end

    it "no player" do
      g = Graph.new(nil)
      expect(g.available?).to be false
      expect(g.title).to be_nil
    end

    it "no ratings" do
      p = FactoryGirl.create(:icu_player)
      g = Graph.new(p)
      expect(g.available?).to be false
      expect(g.icu_ratings).to be_empty
      expect(g.fide_ratings).to be_empty
      range = g.rating_range
      expect(range.first).to be < range.last
      range = g.list_range
      expect(range.first).to be < range.last
    end

    it "one ICU rating" do
      r = FactoryGirl.create(:icu_rating, rating: 2192, list: "2011-09-01")
      g = Graph.new(r.icu_player)
      expect(g.available?).to be true
      expect(g.fide_ratings).to be_empty
      expect(g.icu_ratings).to_not be_empty
      expect(g.icu_ratings.size).to eq(1)
      expect(g.icu_ratings.first.rating).to eq(2192)
      expect(g.icu_ratings.first.list).to be_within(0.01).of(2011.69)
      expect(g.icu_ratings.first.label).to eq("2011 Sep")
      expect(g.min_rating).to eq(2192)
      expect(g.max_rating).to eq(2192)
      expect(g.rating_range.first).to eq(2100)
      expect(g.rating_range.last).to eq(2200)
      expect(g.first_list).to be_within(0.01).of(2011.69)
      expect(g.last_list).to be_within(0.01).of(2011.69)
      expect(g.list_range.first).to eq(2011)
      expect(g.list_range.last).to eq(2012)
    end

    it "one FIDE rating" do
      r = FactoryGirl.create(:fide_rating, rating: 2362, list: "2003-04-01")
      g = Graph.new(r.fide_player)
      expect(g.available?).to be true
      expect(g.icu_ratings).to be_empty
      expect(g.fide_ratings).to_not be_empty
      expect(g.fide_ratings.size).to eq(1)
      expect(g.fide_ratings.first.rating).to eq(2362)
      expect(g.fide_ratings.first.list).to be_within(0.01).of(2003.31)
      expect(g.fide_ratings.first.label).to eq("2003 Apr")
      expect(g.min_rating).to eq(2362)
      expect(g.max_rating).to eq(2362)
      expect(g.rating_range.first).to eq(2300)
      expect(g.rating_range.last).to eq(2400)
      expect(g.first_list).to be_within(0.01).of(2003.31)
      expect(g.last_list).to be_within(0.01).of(2003.31)
      expect(g.list_range.first).to eq(2003)
      expect(g.list_range.last).to eq(2004)
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
      expect(g.available?).to be true
      expect(g.icu_ratings.size).to eq(3)
      expect(g.fide_ratings.size).to eq(2)
      expect(g.min_rating).to eq(2192)
      expect(g.max_rating).to eq(2362)
      expect(g.rating_range.first).to eq(2100)
      expect(g.rating_range.last).to eq(2400)
      expect(g.first_list).to be_within(0.01).of(2003.08)
      expect(g.last_list).to be_within(0.01).of(2011.85)
      expect(g.list_range.first).to eq(2003)
      expect(g.list_range.last).to eq(2012)
    end
  end
end
