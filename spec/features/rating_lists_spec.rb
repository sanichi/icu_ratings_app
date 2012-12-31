require 'spec_helper'

describe "RatingList" do
  describe "#auto_populate" do
    before(:each) do
      login("officer")
      @today = Date.today
      @start = Date.new(2012, 1, 1)
    end

    it "visiting the index should automatically create any missing lists" do
      RatingList.count.should == 0
      visit "/admin/rating_lists"
      RatingList.count.should be > 0
      RatingList.minimum(:date).should be == @start
      RatingList.maximum(:date).should be <= @today
    end
  end
end
