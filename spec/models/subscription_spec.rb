require 'rails_helper'

describe Subscription do
  context "#season" do
    it "should convert a date to the current season" do
      expect(Subscription.season(Time.new(2012,7,21))).to eq("2011-12")
      expect(Subscription.season(Time.new(2012,8,31))).to eq("2011-12")
      expect(Subscription.season(Time.new(2012,9,1))).to eq("2012-13")
      expect(Subscription.season(Time.new(2012,12,31))).to eq("2012-13")
      expect(Subscription.season(Time.new(2013,1,1))).to eq("2012-13")
    end
  end

  context "#last_season" do
    it "should convert a date to the last season" do
      expect(Subscription.last_season(Time.new(2012,7,21))).to eq("2010-11")
      expect(Subscription.last_season(Time.new(2012,8,31))).to eq("2010-11")
      expect(Subscription.last_season(Time.new(2012,9,1))).to eq("2011-12")
      expect(Subscription.last_season(Time.new(2012,9,31))).to eq("2011-12")
      expect(Subscription.last_season(Time.new(2012,10,1))).to eq("2011-12")
      expect(Subscription.last_season(Time.new(2012,12,31))).to eq("2011-12")
      expect(Subscription.last_season(Time.new(2013,1,1))).to eq("2011-12")
    end
  end
end
