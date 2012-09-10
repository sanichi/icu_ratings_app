require 'spec_helper'

describe "Pages" do
  describe "contacts" do
    before(:each) do
      @members   = (1..4).map { |i| FactoryGirl.create(:user, role: "member") }
      @reporters = (1..3).map { |i| FactoryGirl.create(:user, role: "reporter") }
      @officers  = (1..2).map { |i| FactoryGirl.create(:user, role: "officer") }
      @admins    = (1..1).map { |i| FactoryGirl.create(:user, role: "admin") }
    end

    it "should have correctly pluralized headers and correct numbers of contacts under each" do
      visit "/contacts"
      page.should have_no_selector("h3", text: /member/i)
      {
        "Tournament Reporters"  => 3,
        "Rating Officers"       => 2,
        "Website Administrator" => 1,
      }.each_pair do |h, n|
        page.find("h3", text: h).find(:xpath, "following-sibling::ul").all("li").should have(n).items
      end
    end

    it "a single admin becomes an officer if there are no officers" do
      @officers.each { |officer| officer.delete }
      visit "/contacts"
      page.find("h3", text: "Rating Officer").find(:xpath, "following-sibling::ul").all("li").should have(1).items
      page.should have_no_selector("h3", text: "Website Administrator")
    end
  end

  describe "/my_home" do
    before(:each) do
      load_icu_players
      load_old_ratings
      u = FactoryGirl.create(:user, role: "officer")
      @t1, @t2 = %w{bunratty_masters_2011.tab kilkenny_masters_2011.tab}.map do |f|
        t = test_tournament(f, u.id)
        t.move_stage("ready", u)
        t.move_stage("queued", u)
        t.rate!
        t
      end
    end

    it "should not be available to guests" do
      visit "/my_home"
      page.should have_selector("div.flash span.alert", text: "Not authorized")
    end

    it "player with recent tournaments and published ratings" do
      p1 = @t1.players.find_by_last_name("Cafolla")
      p2 = @t2.players.find_by_last_name("Cafolla")
      m1 = p1.icu_player
      FactoryGirl.create(:icu_rating, icu_player: m1, rating: 2000, list: "2012-01-01")
      FactoryGirl.create(:icu_rating, icu_player: m1, rating: 2100, list: "2011-09-01")
      FactoryGirl.create(:icu_rating, icu_player: m1, rating: 1900, list: "2011-05-01")
      u1 = FactoryGirl.create(:user, icu_player: m1)
      login(u1)
      page.should have_selector("div.header span", text: m1.name(false))
      page.should have_selector("table#recent_tournaments")
      page.should have_selector(:xpath, "//table[@id='recent_tournaments']/tr[td='%s']/td[contains(.,'%d')]" % [@t1.name_with_year, p1.rating_change.abs])
      page.should have_selector(:xpath, "//table[@id='recent_tournaments']/tr[td='%s']/td[contains(.,'%d')]" % [@t2.name_with_year, p2.rating_change.abs])
      page.should have_selector("table#published_ratings")
      page.should have_selector(:xpath, "//table[@id='published_ratings']/tr[th='Latest' and td='January 2012' and td='2000']")
      page.should have_selector(:xpath, "//table[@id='published_ratings']/tr[th='Highest' and td='September 2011' and td='2100']")
      page.should have_selector(:xpath, "//table[@id='published_ratings']/tr[th='Lowest' and td='May 2011' and td='1900']")
      page.should have_selector("table#gains_and_losses")
      page.should have_no_selector("table#explanation")
    end

    it "player with recent tournaments but no published ratings" do
      p = @t1.players.find_by_last_name("Fox")
      m = p.icu_player
      u = FactoryGirl.create(:user, icu_player: m)
      login(u)
      page.should have_selector("div.header span", text: m.name(false))
      page.should have_selector("table#recent_tournaments")
      page.should have_no_selector("table#published_ratings")
      page.should have_selector("table#gains_and_losses")
      page.should have_selector("table#explanation")
      page.should have_no_selector("p#explain_rated_tournaments")
    end

    it "player with no recent tournaments but published ratings" do
      m = IcuPlayer.find(90)
      u = FactoryGirl.create(:user, icu_player: m)
      FactoryGirl.create(:icu_rating, icu_player: m, rating: 2000, list: "2012-01-01")
      login(u)
      page.should have_selector("div.header span", text: m.name(false))
      page.should have_no_selector("table#recent_tournaments")
      page.should have_selector("table#published_ratings")
      page.should have_no_selector("table#gains_and_losses")
      page.should have_selector("table#explanation")
      page.should have_selector("p#explain_rated_tournaments")
    end

    it "player with no recent tournaments, no published ratings but with old rating" do
      m = IcuPlayer.find(13001)
      u = FactoryGirl.create(:user, icu_player: m)
      login(u)
      page.should have_selector("div.header span", text: u.icu_player.name(false))
      page.should have_no_selector("table#recent_tournaments")
      page.should have_no_selector("table#published_ratings")
      page.should have_no_selector("table#gains_and_losses")
      page.should have_selector("table#explanation")
      page.should have_selector("p#explain_rated_tournaments")
      page.should have_selector("span#old_rating")
    end

    it "player with no recent tournaments, no published ratings and no old rating" do
      u = FactoryGirl.create(:user)
      login(u)
      page.should have_selector("div.header span", text: u.icu_player.name(false))
      page.should have_no_selector("table#recent_tournaments")
      page.should have_no_selector("table#published_ratings")
      page.should have_no_selector("table#gains_and_losses")
      page.should have_selector("table#explanation")
      page.should have_selector("p#explain_rated_tournaments")
      page.should have_no_selector("span#old_rating")
    end
  end
end
