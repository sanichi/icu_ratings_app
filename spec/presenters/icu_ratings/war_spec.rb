require 'rails_helper'

module IcuRatings
  describe WAR do
    it "enough ratings for a 3 year average" do
      p1 = FactoryGirl.create(:icu_player)
      FactoryGirl.create(:icu_rating, rating: 2000, list: "2008-09-01", icu_player: p1)
      FactoryGirl.create(:icu_rating, rating: 2100, list: "2009-09-01", icu_player: p1)
      FactoryGirl.create(:icu_rating, rating: 2200, list: "2010-09-01", icu_player: p1)
      f1 = FactoryGirl.create(:fide_player, icu_player: p1)
      FactoryGirl.create(:fide_rating, rating: 2000, list: "2008-11-01", fide_player: f1)
      FactoryGirl.create(:fide_rating, rating: 2100, list: "2009-11-01", fide_player: f1)
      FactoryGirl.create(:fide_rating, rating: 2200, list: "2010-11-01", fide_player: f1)
      FactoryGirl.create(:fide_rating, rating: 2300, list: "2011-01-01", fide_player: f1)
      p2 = FactoryGirl.create(:icu_player, gender: "F")
      FactoryGirl.create(:icu_rating, rating: 1200, list: "2008-09-01", icu_player: p2)
      FactoryGirl.create(:icu_rating, rating: 1100, list: "2009-09-01", icu_player: p2)
      FactoryGirl.create(:icu_rating, rating: 1000, list: "2010-09-01", icu_player: p2)
      p3 = FactoryGirl.create(:icu_player)
      FactoryGirl.create(:icu_rating, rating: 1800, list: "2008-09-01", icu_player: p3, full: false)
      FactoryGirl.create(:icu_rating, rating: 1900, list: "2009-09-01", icu_player: p3)
      FactoryGirl.create(:icu_rating, rating: 2000, list: "2010-09-01", icu_player: p3)
      f3 = FactoryGirl.create(:fide_player, icu_player: p3)
      FactoryGirl.create(:fide_rating, rating: 2100, list: "2010-11-01", fide_player: f3)

      w = WAR.new(method: "war")

      expect(w.available?).to be true
      expect(w.years).to eq(3)
      expect(w.lists[:icu].map(&:to_s).join("|")).to eq("2008-09-01|2009-09-01|2010-09-01")
      expect(w.lists[:fide].map(&:to_s).join("|")).to eq("2008-11-01|2009-11-01|2010-11-01")
      expect(w.players.size).to eq(2)
      expect(w.players.first.player).to eq(p1)
      expect(w.players.first.average).to be_within(0.01).of(2130.0)
      expect(w.players.last.player).to eq(p3)
      expect(w.players.last.average).to be_within(0.01).of(2017.5)

      w = WAR.new(method: "war", gender: "F")

      expect(w.available?).to be true
      expect(w.players.size).to eq(1)
      expect(w.players.first.player).to eq(p2)
      expect(w.players.first.average).to be_within(0.01).of(1070.0)

      w = WAR.new(method: "simple")

      expect(w.available?).to be true
      expect(w.years).to eq(1)
      expect(w.lists[:icu].map(&:to_s).join("|")).to eq("2010-09-01")
      expect(w.lists[:fide].map(&:to_s).join("|")).to eq("2010-11-01")
      expect(w.players.size).to eq(2)
      expect(w.players.first.average).to be_within(0.01).of(2200.0)
      expect(w.players.last.average).to be_within(0.01).of(2050.0)
    end

    it "enough ratings for simple average" do
      p1 = FactoryGirl.create(:icu_player)
      FactoryGirl.create(:icu_rating, rating: 2200, list: "2010-09-01", icu_player: p1)
      f1 = FactoryGirl.create(:fide_player, icu_player: p1)
      FactoryGirl.create(:fide_rating, rating: 2200, list: "2010-11-01", fide_player: f1)
      FactoryGirl.create(:fide_rating, rating: 2300, list: "2011-01-01", fide_player: f1)
      p2 = FactoryGirl.create(:icu_player, gender: "F")
      FactoryGirl.create(:icu_rating, rating: 1000, list: "2010-09-01", icu_player: p2)
      p3 = FactoryGirl.create(:icu_player)
      FactoryGirl.create(:icu_rating, rating: 2000, list: "2010-09-01", icu_player: p3)
      f3 = FactoryGirl.create(:fide_player, icu_player: p3)
      FactoryGirl.create(:fide_rating, rating: 2100, list: "2010-11-01", fide_player: f3)

      w = WAR.new(method: "war")

      expect(w.available?).to be false

      w = WAR.new(method: "simple")

      expect(w.available?).to be true
      expect(w.years).to eq(1)
      expect(w.lists[:icu].map(&:to_s).join("|")).to eq("2010-09-01")
      expect(w.lists[:fide].map(&:to_s).join("|")).to eq("2010-11-01")
      expect(w.players.size).to eq(2)
      expect(w.players.first.average).to be_within(0.01).of(2200.0)
      expect(w.players.last.average).to be_within(0.01).of(2050.0)

      w = WAR.new(method: "simple", gender: "F")

      expect(w.available?).to be true
      expect(w.players.size).to eq(1)
      expect(w.players.first.average).to be_within(0.01).of(1000.0)
    end

    it "no data at all" do
      expect(WAR.new(method: "war").available?).to be false
      expect(WAR.new(method: "simple").available?).to be false
    end
  end
end
