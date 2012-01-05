require 'spec_helper'

module IcuRatings
  describe Juniors do
    describe "insufficient data" do
      it "should be unavailable" do
        j = Juniors.new({})
        j.available?.should be_false
        j.ratings.should be_empty
      end
    end

    describe "enough data" do
      before(:each) do
        Date.stub!(:today).and_return(Date.new(2011, 12, 17))
        @list = "2011-09-01"
        @p1 = Factory(:icu_player, dob: "2000-08-02", gender: "F")
        @p2 = Factory(:icu_player, dob: "2000-08-01")
        @p3 = Factory(:icu_player, dob: "1991-01-01")
        @p4 = Factory(:icu_player, dob: "1950-05-31")
        @p5 = Factory(:icu_player, dob: "1995-06-01", fed: "RUS")
        @r1 = Factory(:icu_rating, list: @list, icu_player: @p1)
        @r5 = Factory(:icu_rating, list: "2011-05-01", icu_player: @p1)
        @r2 = Factory(:icu_rating, list: @list, icu_player: @p2)
        @r3 = Factory(:icu_rating, list: @list, icu_player: @p3)
        @r4 = Factory(:icu_rating, list: @list, icu_player: @p4)
        @r6 = Factory(:icu_rating, list: @list, icu_player: @p5)
      end

      it "default settings" do
        params = {}
        j = Juniors.new(params)
        j.available?.should be_true
        params[:date].should == "2011-12-17"
        params[:under].should == "21"
        params[:least].should == "0"
        j.list.to_s.should == @list
        ratings = j.ratings
        ratings.size.should == 3
        ratings.should include(@r1)
        ratings.should include(@r2)
        ratings.should include(@r3)
        date_range = j.date_range
        date_range.size.should == 14
        date_range.first.should == "2011-06-01"
        date_range.last.should == "2012-06-01"
      end

      it "narrow age range" do
        j = Juniors.new(date: "2011-09-01", under: "12", least: "11")
        ratings = j.ratings
        ratings.size.should == 2
        ratings.should include(@r1)
        ratings.should include(@r2)
        j = Juniors.new(date: "2011-09-01", under: "12", least: "11", gender: "F")
        ratings = j.ratings
        ratings.size.should == 1
        ratings.should include(@r1)
        j = Juniors.new(date: "2011-08-01", under: "12", least: "11")
        ratings = j.ratings
        ratings.size.should == 1
        ratings.should include(@r2)
        j = Juniors.new(date: "2011-07-01", under: "12", least: "11")
        ratings = j.ratings
        ratings.size.should == 0
      end

      it "wide age range" do
        j = Juniors.new(date: "2011-12-01", under: "21", least: "8")
        ratings = j.ratings
        ratings.size.should == 3
        ratings.should include(@r1)
        ratings.should include(@r2)
        ratings.should include(@r3)
        j = Juniors.new(date: "2012-01-01", under: "21", least: "8")
        ratings = j.ratings
        ratings.size.should == 2
        ratings.should include(@r1)
        ratings.should include(@r2)
      end
    end
  end
end
