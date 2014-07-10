require 'spec_helper'

describe OldRating do
  it "factory" do
    old = FactoryGirl.create(:old_rating, icu_id: 1350)
    old.id.should == 1
    old.icu_id.should == 1350
    old.rating.should be <= 2400
    old.games.should be <= 500
    old.full.should be true
    old = FactoryGirl.create(:old_rating, icu_id: 159, rating: 2198, games: 329, full: false)
    old.id.should == 2
    old.icu_id.should == 159
    old.rating.should == 2198
    old.games.should == 329
    old.full.should be false
  end

  it "yaml file" do
    OldRating.count.should == 0
    load_old_ratings
    size = OldRating.count
    size.should be > 0
    cafolla = OldRating.find_by_icu_id(159)
    cafolla.rating.should == 1982
    cafolla.games.should == 1111
    cafolla.full.should be true
    load_old_ratings
    OldRating.count.should == size
  end
end
