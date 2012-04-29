require 'spec_helper'

describe "Player" do
  describe "matching" do
    before(:each) do
      test = "junior_championships_u19_2010.txt"
      load_icu_players_for(test)
      u = login("officer")
      FactoryGirl.create(:fide_player, id: 2502054, icu_player: IcuPlayer.find(6897), first_name: "Ryan-Rhys", last_name: "Griffiths", gender: "M", rating: 2200)
      @t = test_tournament(test, u.id)
      @t.reset_status
    end

    it "test should be setup correctly" do
      @t.status.should == "ok"
      @t.stage.should == "initial"
      p = IcuPlayer.find(6897)
      p.should_not be_nil
      f = FidePlayer.find(2502054)
      f.should_not be_nil
      f.icu_id.should == 6897
    end

    it "should allow an ICU player match", js: true do
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      page.should have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Date of birth']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='']")
      click_link("Find ICU Player")
      click_link("Link tournament player to this ICU player")
      page.should have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='2502054']")
      page.should have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='IRL']")
      page.should have_selector(:xpath, "//th[.='Date of birth']/following-sibling::td[.='1993-12-20']")
      page.should have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='M']")
    end

    it "should allow a FIDE player match", js: true do
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      page.should have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='']")
      page.should have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='']")
      click_link("Find FIDE Player")
      click_link("Link tournament player to this FIDE player")
      page.should have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='2502054']")
      page.should have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='IRL']")
      page.should have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='M']")
      page.should have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2200']")
    end

    it "a FIDE player match should not update an existing FIDE rating for the player", js: true do
      p = Player.where(icu_id: 6897).first
      p.update_column(:fide_rating, 2300)
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      page.should have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2300']")
      click_link("Find FIDE Player")
      click_link("Link tournament player to this FIDE player")
      page.should have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2300']")
    end
  end
end
