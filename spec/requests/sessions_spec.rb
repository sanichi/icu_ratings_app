require 'spec_helper'

describe "Sessions" do
  describe "logging in" do
    before(:each) do
      @user = Factory(:user)
      @loser = Factory(:user, :expiry => 1.year.ago.at_end_of_year)
      visit "/log_in"
    end
    
    it "login page" do
      page.should have_selector("head title", :text => "Log in")
      page.should have_xpath("//form//input[@name='email']")
      page.should have_xpath("//form//input[@name='password']")
    end

    it "invalid emails should fail" do
      page.fill_in "Email", :with => "wrong_email@icu.ie"
      page.fill_in "Password", :with => @user.password
      click_button "Log in"
      page.should have_selector("head title", :text => "Log in")
      page.should have_selector("span.alert", :text => /invalid email or password/i)
      Login.count.should == 0
    end

    it "invalid passwords should fail" do
      page.fill_in "Email", :with => @user.email
      page.fill_in "Password", :with => "wrong password"
      click_button "Log in"
      page.should have_selector("head title", :text => "Log in")
      page.should have_selector("span.alert", :text => /invalid email or password/i)
      @user.logins.where(:problem => "password", :role => "member").count.should == 1
    end

    it "expired members should fail" do
      page.fill_in "Email", :with => @loser.email
      page.fill_in "Password", :with => @loser.password
      click_button "Log in"
      page.should have_selector("head title", :text => "Log in")
      page.should have_selector("span.alert", :text => /membership expired/i)
      @loser.logins.where(:problem => "expiry", :role => "member").count.should == 1
    end

    it "valid logins should succeed" do
      page.fill_in "Email", :with => @user.email
      page.fill_in "Password", :with => @user.password
      click_button "Log in"
      page.should have_selector("span.notice", :text => /logged in as #{@user.icu_player.name(false)}/i)
      @user.logins.where(:problem => "none", :role => "member").count.should == 1
    end

    it "the user's current role is recorded" do
      page.fill_in "Email", :with => @user.email
      page.fill_in "Password", :with => @user.password
      click_button "Log in"
      @user.logins.where(:problem => "none").count.should == 1
      @user.logins.where(:problem => "none", :role => "member").count.should == 1
      @user.role = "reporter"
      @user.save
      visit "/log_in"
      page.fill_in "Email", :with => @user.email
      page.fill_in "Password", :with => @user.password
      click_button "Log in"
      @user.logins.where(:problem => "none").count.should == 2
      @user.logins.where(:problem => "none", :role => "member").count.should == 1
      @user.logins.where(:problem => "none", :role => "reporter").count.should == 1
    end
  end
end
