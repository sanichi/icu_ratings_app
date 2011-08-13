require 'spec_helper'

describe SessionsController do
  render_views

  describe "GET log_in (new)" do
    it "should be successful" do
      visit log_in_path
      response.should be_success
    end
  end

  describe "POST create" do
    before(:each) do
      @user = Factory(:user)
    end

    it "should log in a valid user" do
      visit log_in_path
      page.fill_in "Email", :with => @user.email
      page.fill_in "Password", :with => @user.password
      click_button "Log in"
      page.should have_selector("span.notice", :text => /logged in as #{@user.icu_player.name(false)}/i)
    end
  end
end
