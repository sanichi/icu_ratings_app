require 'rails_helper'

describe OldRating do
  it "factory" do
    old = FactoryGirl.create(:old_rating, icu_id: 1350)
    expect(old.id).to eq(1)
    expect(old.icu_id).to eq(1350)
    expect(old.rating).to be <= 2400
    expect(old.games).to be <= 500
    expect(old.full).to be true
    old = FactoryGirl.create(:old_rating, icu_id: 159, rating: 2198, games: 329, full: false)
    expect(old.id).to eq(2)
    expect(old.icu_id).to eq(159)
    expect(old.rating).to eq(2198)
    expect(old.games).to eq(329)
    expect(old.full).to be false
  end

  it "yaml file" do
    expect(OldRating.count).to eq(0)
    load_old_ratings
    size = OldRating.count
    expect(size).to be > 0
    cafolla = OldRating.find_by_icu_id(159)
    expect(cafolla.rating).to eq(1982)
    expect(cafolla.games).to eq(1111)
    expect(cafolla.full).to be true
    load_old_ratings
    expect(OldRating.count).to eq(size)
  end
end
