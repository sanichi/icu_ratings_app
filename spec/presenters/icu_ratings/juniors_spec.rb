require 'spec_helper'

module IcuRatings
  describe Juniors do
    describe "insufficient data" do
      it "should be unavailable" do
        j = Juniors.new({})
        expect(j.available?).to be false
        expect(j.ratings).to be_empty
      end
    end

    describe "enough data" do
      before(:each) do
        allow(Date).to receive(:today).and_return(Date.new(2011, 12, 17))
        @list = "2011-09-01"
        @p1 = FactoryGirl.create(:icu_player, dob: "2000-08-02", gender: "F")
        @p2 = FactoryGirl.create(:icu_player, dob: "2000-08-01")
        @p3 = FactoryGirl.create(:icu_player, dob: "1991-01-01")
        @p4 = FactoryGirl.create(:icu_player, dob: "1950-05-31")
        @p5 = FactoryGirl.create(:icu_player, dob: "1995-06-01", fed: "RUS")
        @r1 = FactoryGirl.create(:icu_rating, list: @list, icu_player: @p1)
        @r5 = FactoryGirl.create(:icu_rating, list: "2011-05-01", icu_player: @p1)
        @r2 = FactoryGirl.create(:icu_rating, list: @list, icu_player: @p2)
        @r3 = FactoryGirl.create(:icu_rating, list: @list, icu_player: @p3)
        @r4 = FactoryGirl.create(:icu_rating, list: @list, icu_player: @p4)
        @r6 = FactoryGirl.create(:icu_rating, list: @list, icu_player: @p5)
      end

      it "default settings" do
        params = {}
        j = Juniors.new(params)
        expect(j.available?).to be true
        expect(params[:date]).to eq("2011-12-17")
        expect(params[:under]).to eq("21")
        expect(params[:least]).to eq("0")
        expect(j.list.to_s).to eq(@list)
        ratings = j.ratings
        expect(ratings.size).to eq(3)
        expect(ratings).to include(@r1)
        expect(ratings).to include(@r2)
        expect(ratings).to include(@r3)
        date_range = j.date_range
        expect(date_range.size).to eq(14)
        expect(date_range.first).to eq("2011-01-01")
        expect(date_range.last).to eq("2012-01-01")
      end

      it "narrow age range" do
        j = Juniors.new(date: "2011-09-01", under: "12", least: "11")
        ratings = j.ratings
        expect(ratings.size).to eq(2)
        expect(ratings).to include(@r1)
        expect(ratings).to include(@r2)
        j = Juniors.new(date: "2011-09-01", under: "12", least: "11", gender: "F")
        ratings = j.ratings
        expect(ratings.size).to eq(1)
        expect(ratings).to include(@r1)
        j = Juniors.new(date: "2011-08-01", under: "12", least: "11")
        ratings = j.ratings
        expect(ratings.size).to eq(1)
        expect(ratings).to include(@r2)
        j = Juniors.new(date: "2011-07-01", under: "12", least: "11")
        ratings = j.ratings
        expect(ratings.size).to eq(0)
      end

      it "wide age range" do
        j = Juniors.new(date: "2011-12-01", under: "21", least: "8")
        ratings = j.ratings
        expect(ratings.size).to eq(3)
        expect(ratings).to include(@r1)
        expect(ratings).to include(@r2)
        expect(ratings).to include(@r3)
        j = Juniors.new(date: "2012-01-01", under: "21", least: "8")
        ratings = j.ratings
        expect(ratings.size).to eq(2)
        expect(ratings).to include(@r1)
        expect(ratings).to include(@r2)
      end
    end

    describe "beginning of month" do
      before(:each) do
        @today = Date.new(2012, 2, 1)
        allow(Date).to receive(:today).and_return(@today)
      end

      it "date range" do
        j = Juniors.new({})
        expect(j.date_range.size).to eq(13)
        expect(j.date_range.first).to eq("2012-01-01")
        expect(j.date_range.last).to eq("2013-01-01")
      end
    end

    describe "beginning of year" do
      before(:each) do
        @today = Date.new(2012, 1, 1)
        allow(Date).to receive(:today).and_return(@today)
      end

      it "date range" do
        j = Juniors.new({})
        expect(j.date_range.size).to eq(13)
        expect(j.date_range.first).to eq("2012-01-01")
        expect(j.date_range.last).to eq("2013-01-01")
      end
    end

    describe "end of year" do
      before(:each) do
        @today = Date.new(2012, 12, 31)
        allow(Date).to receive(:today).and_return(@today)
      end

      it "date range" do
        j = Juniors.new({})
        expect(j.date_range.size).to eq(14)
        expect(j.date_range.first).to eq("2012-01-01")
        expect(j.date_range.last).to eq("2013-01-01")
      end
    end
  end
end
