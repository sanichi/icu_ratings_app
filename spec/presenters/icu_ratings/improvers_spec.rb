require 'rails_helper'

module IcuRatings
  describe Improvers do
    describe "insufficient data" do
      it "should be unavailable if there are no rating lists" do
        i = Improvers.new({})
        expect(i.available?).to be false
      end

      it "should be unavailable if there is only one rating list" do
        FactoryGirl.create(:icu_rating, list: "2011-09-01", icu_player: FactoryGirl.create(:icu_player))
        i = Improvers.new({})
        expect(i.available?).to be false
      end
    end

    describe "enough data" do
      before(:each) do
        @l1 = "2010-09-01"
        @l2 = "2011-01-01"
        @l3 = "2011-05-01"
        @l4 = "2011-09-01"

        @p1 = FactoryGirl.create(:icu_player)
        FactoryGirl.create(:icu_rating, list: @l1, rating: 1000, icu_player: @p1)
        FactoryGirl.create(:icu_rating, list: @l2, rating: 1500, icu_player: @p1)
        FactoryGirl.create(:icu_rating, list: @l3, rating: 1500, icu_player: @p1)
        FactoryGirl.create(:icu_rating, list: @l4, rating: 2000, icu_player: @p1)

        @p2 = FactoryGirl.create(:icu_player)
        FactoryGirl.create(:icu_rating, list: @l1, rating: 1400, icu_player: @p2)
        FactoryGirl.create(:icu_rating, list: @l2, rating: 1500, icu_player: @p2)
        FactoryGirl.create(:icu_rating, list: @l3, rating: 1600, icu_player: @p2)
        FactoryGirl.create(:icu_rating, list: @l4, rating: 1700, icu_player: @p2)

        FactoryGirl.create(:icu_rating, list: @l1, icu_player: FactoryGirl.create(:icu_player))
        FactoryGirl.create(:icu_rating, list: @l2, icu_player: FactoryGirl.create(:icu_player))
        FactoryGirl.create(:icu_rating, list: @l3, icu_player: FactoryGirl.create(:icu_player))
        FactoryGirl.create(:icu_rating, list: @l4, icu_player: FactoryGirl.create(:icu_player))
      end

      it "default settings" do
        params = {}
        i = Improvers.new(params)
        expect(i.available?).to be true
        expect(i.from.to_s).to eq(@l1)
        expect(i.upto.to_s).to eq(@l4)
        expect(i.rows.size).to eq(2)
        expect(i.rows.first.player.id).to eq(@p1.id)
        expect(i.rows.first.diff).to eq(1000)
        expect(i.rows.last.player.id).to eq(@p2.id)
        expect(i.rows.last.diff).to eq(300)
      end

      it "specific lists" do
        params = { from: @l2, upto: @l3 }
        i = Improvers.new(params)
        expect(i.available?).to be true
        expect(i.from.to_s).to eq(@l2)
        expect(i.upto.to_s).to eq(@l3)
        expect(i.rows.size).to eq(2)
        expect(i.rows.first.player.id).to eq(@p2.id)
        expect(i.rows.first.diff).to eq(100)
        expect(i.rows.last.player.id).to eq(@p1.id)
        expect(i.rows.last.diff).to eq(0)
      end
    end
  end
end
