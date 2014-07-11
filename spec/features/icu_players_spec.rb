require 'rails_helper'

describe IcuPlayer do
  describe "show" do
    describe "member" do
      before(:each) do
        @player = FactoryGirl.create(:icu_player, title: "IM", club: "Bangor", dob: "1955-09-11", joined: "1976-09-01")
        @user = FactoryGirl.create(:user, icu_player: @player)
        login(@user)
      end

      it "can access their own details" do
        click_link @player.name(false)
        expect(page).to have_selector("div.blurb span", text: /logged in as member/i)
        expect(page).to have_selector(:xpath, %{//tr[th[.='First Name']]/td[.="#{@player.first_name}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Last Name']]/td[.="#{@player.last_name}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Date of Birth']]/td[.="#{@player.dob}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Gender']]/td[.='M']})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Club']]/td[.='Bangor']})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Email']]/td[.="#{@player.email}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='ID']]/td[.="#{@player.id}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Date joined']]/td[.="#{@player.joined}"]})
        expect(page).to have_selector(:xpath, %{//tr[th[.='ID']]/td[.='None']})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Federation']]/td[.='IRL']})
        expect(page).to have_selector(:xpath, %{//tr[th[.='Title']]/td[.='IM']})
        expect(page).to have_selector("div.blurb span", text: /if.*wrong.*please contact/i)
      end

      it "cannot access another user's details" do
        login("member")
        expect(page).to have_no_link "#{@player.name} (#{@user.role})"
        visit icu_player_path(@player)
        expect(page).to have_selector("span.alert", text: /not authorized/i)
      end
    end

    describe "reporter" do
      before(:each) do
        @player = FactoryGirl.create(:icu_player)
        @user = FactoryGirl.create(:user, icu_player: @player, role: "reporter")
        @member = FactoryGirl.create(:icu_player)
        login(@user)
      end

      it "can access their own details" do
        click_link @player.name(false)
        expect(page).to have_selector("div.blurb span", text: /logged in as tournament reporter/i)
        expect(page).to have_selector(:xpath, %{//tr[th[.='ID']]/td[.="#{@player.id}"]})
        expect(page).to have_selector("div.blurb span", text: /if.*wrong.*please contact/i)
      end

      it "can also access another user's details" do
        visit icu_player_path(@member)
        expect(page).to have_no_selector("div.blurb span", text: /logged in as/i)
        expect(page).to have_selector(:xpath, "//tr[th[.='ID']]/td[.='#{@member.id}']")
        expect(page).to have_no_selector("div.blurb span", text: /please contact/i)
      end
    end
  end
end
