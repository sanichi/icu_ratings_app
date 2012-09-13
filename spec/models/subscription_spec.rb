require 'spec_helper'

describe Subscription do
  context "#season" do
    it "should convert a date to the current season" do
      Subscription.season(Time.new(2012,7,21)).should == "2011-12"
      Subscription.season(Time.new(2012,8,31)).should == "2011-12"
      Subscription.season(Time.new(2012,9,1)).should == "2012-13"
      Subscription.season(Time.new(2012,12,31)).should == "2012-13"
      Subscription.season(Time.new(2013,1,1)).should == "2012-13"
    end
  end

  context "#last_season" do
    it "should convert a date to the last season" do
      Subscription.last_season(Time.new(2012,7,21)).should == "2010-11"
      Subscription.last_season(Time.new(2012,8,31)).should == "2010-11"
      Subscription.last_season(Time.new(2012,9,1)).should == "2011-12"
      Subscription.last_season(Time.new(2012,9,31)).should == "2011-12"
      Subscription.last_season(Time.new(2012,10,1)).should == "2011-12"
      Subscription.last_season(Time.new(2012,12,31)).should == "2011-12"
      Subscription.last_season(Time.new(2013,1,1)).should == "2011-12"
    end
  end
end
