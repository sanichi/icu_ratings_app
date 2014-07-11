require 'rails_helper'

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
      expect(@t.status).to eq("ok")
      expect(@t.stage).to eq("initial")
      p = IcuPlayer.find(6897)
      expect(p).to_not be_nil
      f = FidePlayer.find(2502054)
      expect(f).to_not be_nil
      expect(f.icu_id).to eq(6897)
    end

    it "should allow an ICU player match", js: true do
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      expect(page).to have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Date of birth']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='']")
      click_link("Find ICU Player")
      click_link("Link tournament player to this ICU player")
      expect(page).to have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='2502054']")
      expect(page).to have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='IRL']")
      expect(page).to have_selector(:xpath, "//th[.='Date of birth']/following-sibling::td[.='1993-12-20']")
      expect(page).to have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='M']")
    end

    it "should allow a FIDE player match", js: true do
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      expect(page).to have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='']")
      expect(page).to have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='']")
      click_link("Find FIDE Player")
      click_link("Link tournament player to this FIDE player")
      expect(page).to have_selector(:xpath, "//th[.='FIDE ID']/following-sibling::td[.='2502054']")
      expect(page).to have_selector(:xpath, "//th[.='Federation']/following-sibling::td[.='IRL']")
      expect(page).to have_selector(:xpath, "//th[.='Gender']/following-sibling::td[.='M']")
      expect(page).to have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2200']")
    end

    it "a FIDE player match should not update an existing FIDE rating for the player", js: true do
      p = Player.where(icu_id: 6897).first
      p.update_column(:fide_rating, 2300)
      visit "/admin/tournaments/#{@t.id}"
      click_link("Griffiths, Ryan-Rhys")
      expect(page).to have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2300']")
      click_link("Find FIDE Player")
      click_link("Link tournament player to this FIDE player")
      expect(page).to have_selector(:xpath, "//th[.='Elo rating']/following-sibling::td[.='2300']")
    end
  end
end
