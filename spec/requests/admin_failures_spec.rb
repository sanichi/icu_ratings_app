require 'spec_helper'

describe "Failure" do
  describe "administrators" do
    before(:each) do
      20.times { Factory(:failure) }
      login("admin")
    end

    it "can list with pagination" do
      visit "admin/failures"
      page.should have_selector("td", :text => "RuntimeError", :count => 15)
      click_link "next"
      page.should have_selector("td", :text => "RuntimeError", :count => 5)
      page.should have_no_link("next")
      page.should have_link("prev")
    end
  end

  describe "non-administrators" do
    it "cannot simulate" do
      %w[guest member reporter officer].each do |role|
        login(role) unless role == "guest"
        visit "/admin/failures/new"
        page.should have_selector("span.alert", :text => /authoriz/i)
        Failure.count.should == 0
      end
    end
  end
end
