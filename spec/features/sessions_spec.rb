require 'rails_helper'

describe "Sessions" do
  describe "logging in" do
    before(:each) do
      @user = FactoryGirl.create(:user)
      @loser = FactoryGirl.create(:user, expiry: 1.year.ago.at_end_of_year)
      visit "/log_in"
    end

    it "login page" do
      expect(page).to have_title("Log in")
      expect(page).to have_xpath("//form//input[@name='email']")
      expect(page).to have_xpath("//form//input[@name='password']")
    end

    it "invalid emails should fail" do
      page.fill_in "Email", with: "wrong_email@icu.ie"
      page.fill_in "Password", with: @user.password
      click_button "Log in"
      expect(page).to have_title("Log in")
      expect(page).to have_selector("span.alert", text: /invalid email or password/i)
      expect(Login.count).to eq(0)
    end

    it "invalid passwords should fail" do
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: "wrong password"
      click_button "Log in"
      expect(page).to have_title("Log in")
      expect(page).to have_selector("span.alert", text: /invalid email or password/i)
      expect(@user.logins.where(problem: "password", role: "member").count).to eq(1)
    end

    it "expired members should fail" do
      page.fill_in "Email", with: @loser.email
      page.fill_in "Password", with: @loser.password
      click_button "Log in"
      expect(page).to have_title("Log in")
      expect(page).to have_selector("span.alert", text: /suspended/i)
      expect(@loser.logins.where(problem: "expiry", role: "member").count).to eq(1)
    end

    it "valid logins should succeed" do
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: @user.password
      click_button "Log in"
      expect(page).to have_selector("div.header span", text: @user.icu_player.name(false))
      expect(@user.logins.where(problem: "none", role: "member").count).to eq(1)
    end

    it "the user's current role is recorded" do
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: @user.password
      click_button "Log in"
      expect(@user.logins.where(problem: "none").count).to eq(1)
      expect(@user.logins.where(problem: "none", role: "member").count).to eq(1)
      @user.role = "reporter"
      @user.save
      visit "/log_in"
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: @user.password
      click_button "Log in"
      expect(@user.logins.where(problem: "none").count).to eq(2)
      expect(@user.logins.where(problem: "none", role: "member").count).to eq(1)
      expect(@user.logins.where(problem: "none", role: "reporter").count).to eq(1)
    end
  end

  describe "pulling recently updated member data" do
    before(:each) do
      salt = "b3f0f553a916b0e8ab6b2469cabd200f"
      @password = [0, 1].map do |i|
        pass = "password#{i}"
        { password: pass, encrypted: eval(Rails.application.secrets.hasher) }
      end
      @user = FactoryGirl.create(:user, salt: salt, password: @password[0].fetch(:encrypted))
      visit "/log_in"
    end

    before(:all) do
      User.pulls_disabled = false
    end

    after(:all) do
      User.pulls_disabled = true
    end

    it "valid logins avoid the need for pulls" do
      expect(ICU::Database::Pull).to_not receive(:new)
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: @password[0].fetch(:password)
      click_button "Log in"
      @user.reload
      expect(@user.logins.where(problem: "none").count).to eq(1)
      expect(@user.last_pulled_at).to be_nil
      expect(@user.last_pull).to be_nil
    end

    it "invalid logins triggers pulls to check for changes" do
      hash = [:password, :salt, :status, :expiry].inject({}) { |h,k| h[k] = @user.send(k); h }
      allow(ICU::Database::Pull).to receive_message_chain(:new, :get_user).with(@user.id, @user.email).and_return(hash)
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: "rubbish"
      click_button "Log in"
      @user.reload
      expect(@user.logins.where(problem: "password").count).to eq(1)
      expect(@user.last_pulled_at).to_not be_nil
      expect(@user.last_pull).to eq("none")
    end

    it "an out of date date password can be refreshed from pulled data" do
      hash = [:salt, :status, :expiry].inject({}) { |h,k| h[k] = @user.send(k); h }.merge(password: @password[1].fetch(:encrypted))
      allow(ICU::Database::Pull).to receive_message_chain(:new, :get_user).with(@user.id, @user.email).and_return(hash)
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: @password[1].fetch(:password)
      click_button "Log in"
      @user.reload
      expect(@user.logins.where(problem: "none").count).to eq(1)
      expect(@user.last_pulled_at).to_not be_nil
      expect(@user.last_pull).to eq("password")
    end

    it "data is never pulled more than once in quick succession" do
      hash = [:salt, :status, :expiry, :password].inject({}) { |h,k| h[k] = @user.send(k); h }
      allow(ICU::Database::Pull).to receive_message_chain(:new, :get_user).with(@user.id, @user.email).and_return(hash)
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: "rubbish"
      click_button "Log in"
      @user.reload
      expect(@user.logins.where(problem: "password").count).to eq(1)
      last_pulled_at = @user.last_pulled_at
      sleep 1
      visit "/log_in"
      page.fill_in "Email", with: @user.email
      page.fill_in "Password", with: "more rubbish"
      click_button "Log in"
      @user.reload
      expect(@user.logins.where(problem: "password").count).to eq(2)
      expect(@user.last_pulled_at).to eq(last_pulled_at)
    end
  end

  describe "switching user" do
    it "from a member, reporter or officer it logs an event" do
      login("member")
      expect(Login.count).to eq(1)
      login("reporter")
      expect(Login.count).to eq(2)
      login("officer")
      expect(Login.count).to eq(3)
      login("admin")
      expect(Login.count).to eq(4)
    end

    it "from an admin, it does not log an event" do
      login("admin")
      expect(Login.count).to eq(1)
      login("member")
      expect(Login.count).to eq(1)
      login("admin")
      expect(Login.count).to eq(2)
      login("reporter")
      expect(Login.count).to eq(2)
      login("admin")
      expect(Login.count).to eq(3)
      login("reporter")
      expect(Login.count).to eq(3)
    end
  end
end
