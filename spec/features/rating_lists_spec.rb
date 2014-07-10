require 'spec_helper'

describe "RatingList" do
  describe "#auto_populate" do
    before(:each) do
      login("officer")
      @today = Date.today
      @start = Date.new(2012, 1, 1)
    end

    it "visiting the index should automatically create any missing lists" do
      expect(RatingList.count).to eq(0)
      visit "/admin/rating_lists"
      expect(RatingList.count).to be > 0
      expect(RatingList.minimum(:date)).to eq(@start)
      expect(RatingList.maximum(:date)).to be <= @today
    end
  end
end
