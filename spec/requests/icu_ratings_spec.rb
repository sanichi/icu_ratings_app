require 'spec_helper'

describe IcuRating do
  describe "list", js: true do
    before(:each) do
      @r1 = Factory(:icu_rating, list: "2011-09-01", full:true,  icu_player: Factory(:icu_player, club: "Bangor", fed: "IRL"))
      @r2 = Factory(:icu_rating, list: "2011-09-01", full:false, icu_player: Factory(:icu_player, club: "Galway", fed: "IRL", gender: "F"))
      @r3 = Factory(:icu_rating, list: "2011-09-01", full:true,  icu_player: Factory(:icu_player, club: nil,      fed: "SCO"))
      @r4 = Factory(:icu_rating, list: "2011-05-01", full:true,  icu_player: Factory(:icu_player, club: nil,      fed:  nil ))
      @r5 = Factory(:icu_rating, list: "2011-05-01", full:false, icu_player: @r1.icu_player)
      @xp = "#icu_rating_results table tr"
    end

    it "unfiltered" do
      visit icu_ratings_path
      page.should have_selector(@xp, count: 6)
    end

    it "rating list" do
      visit icu_ratings_path
      page.select "2011 Sep", from: "list"
      click_button "Search"
      page.should have_selector(@xp, count: 4)
    end

    it "club" do
      visit icu_ratings_path
      page.select "Bangor", from: "club"
      click_button "Search"
      page.should have_selector(@xp, count: 3)
    end

    it "gender" do
      visit icu_ratings_path
      page.select "Male", from: "gender"
      click_button "Search"
      page.should have_selector(@xp, count: 5)
      page.select "Female", from: "gender"
      click_button "Search"
      page.should have_selector(@xp, count: 2)
    end

    it "federation" do
      visit icu_ratings_path
      page.select "Ireland", from: "fed"
      click_button "Search"
      page.should have_selector(@xp, count: 4)
      page.select "Scotland", from: "fed"
      click_button "Search"
      page.should have_selector(@xp, count: 2)
      page.select "Ireland or Unknown", from: "fed"
      click_button "Search"
      page.should have_selector(@xp, count: 5)
    end

    it "ICU ID" do
      visit icu_ratings_path
      page.fill_in "ICU ID", with: @r1.icu_player.id
      click_button "Search"
      page.should have_selector(@xp, count: 3)
    end

    it "full or provisional" do
      visit icu_ratings_path
      page.select "Full", from: "type"
      click_button "Search"
      page.should have_selector(@xp, count: 4)
      page.select "Provisional", from: "type"
      click_button "Search"
      page.should have_selector(@xp, count: 3)
    end
  end
end
