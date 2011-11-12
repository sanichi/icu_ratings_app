require 'spec_helper'

describe OldRating do
  it "factory_girl" do
    old = Factory(:old_rating)
    old.rating.should be <= 2400
    old.games.should be <= 2400
    old.full.should be_true
    old = Factory(:old_rating, icu_player: Factory(:icu_player, id: 1350), rating: 2198, games: 329)
    old.icu_id.should == 1350
    old.rating.should == 2198
    old.games.should == 329
    old.full.should be_true
    old = Factory(:old_rating, icu_player: Factory(:icu_player, first_name: "Mark"), rating: 700, games: 10, full: false)
    old.icu_player.first_name.should == "Mark"
    old.rating.should == 700
    old.games.should == 10
    old.full.should be_false
    old = Factory(:old_rating, icu_player: nil)
    old.icu_id.should be_nil
  end
end
