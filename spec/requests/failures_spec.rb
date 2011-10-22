require 'spec_helper'

describe "Failure" do
  describe "administrators" do
    before(:each) do
      login("admin")
    end

    it "listing" do
      20.times { Factory(:failure) }
      visit "/admin/failures"
      page.should have_selector("td", :text => "RuntimeError", :count => 15)
      click_link "next"
      page.should have_selector("td", :text => "RuntimeError", :count => 5)
      page.should have_no_link("next")
      page.should have_link("prev")
    end

    it "details", js: true do
      Factory(:failure, details: "Woopsee!")
      visit "/admin/failures"
      click_link "Show failure details"
      page.should have_selector("pre", :text => "Woopsee!")
    end
    
    it "simulation" do
      Failure.count.should == 0
      lambda { visit "/admin/failures/new" }.should raise_error("Simulated Failure")
      Failure.count.should == 1
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
