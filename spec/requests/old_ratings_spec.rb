require 'spec_helper'

describe "OldRating" do
  describe "listing" do
    before(:each) do
      login("reporter")
      Factory(:old_rating, rating: 2198, games: 329, icu_player: Factory(:icu_player, id: 1350, first_name: "Mark", last_name: "Orr"))
      Factory(:old_rating, rating: 1349, games: 51, icu_player: Factory(:icu_player, id: 1349, first_name: "John", last_name: "Orr"))
      Factory(:old_rating, rating: -58, games: 4, full: false, icu_player: Factory(:icu_player, id: 10349, first_name: "Aoife", last_name: "Bannon"))
      @fmt1 = "//div[@id='old_rating_results']/table//tr[td[.='%s'] and td[.='%d'] and td[.='%d'] and td[.='%d'] and td[.='%s']]"
      @fmt2 = "//div[@id='old_rating_results']/table//tr[td[.='%d']]"
    end

    it "list can be searched for names, IDs and types", js: true do
      visit "/admin/old_ratings"
      page.should have_selector("#old_rating_results table tr", count: 4)
      page.should have_selector(:xpath, @fmt1 % ["Orr, Mark", 1350, 2198, 329, "full"])
      page.should have_selector(:xpath, @fmt1 % ["Orr, John", 1349, 1349, 51, "full"])
      page.should have_selector(:xpath, @fmt1 % ["Bannon, Aoife", 10349, -58, 4, "provisional"])
      page.fill_in "Last Name", with: "Orr"
      click_button "Search"
      page.should have_selector("#old_rating_results table tr", count: 3)
      page.should have_selector(:xpath, @fmt2 % 1350)
      page.should have_selector(:xpath, @fmt2 % 1349)
      page.fill_in "Last Name", with: ""
      page.fill_in "First Name", with: "Mark"
      click_button "Search"
      page.should have_selector("#old_rating_results table tr", count: 2)
      page.should have_selector(:xpath, @fmt2 % 1350)
      page.fill_in "First Name", with: ""
      page.select "Provisional", from: "type"
      click_button "Search"
      page.should have_selector("#old_rating_results table tr", count: 2)
      page.should have_selector(:xpath, @fmt2 % 10349)
      page.fill_in "First Name", with: "John"
      click_button "Search"
      page.should have_selector("#old_rating_results table tr", count: 2)
      page.should have_selector("td", text: /no matches/i)
    end
  end
end
