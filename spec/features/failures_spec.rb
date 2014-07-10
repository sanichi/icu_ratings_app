require 'spec_helper'

describe "Failure" do
  describe "administrators" do
    before(:each) do
      login("admin")
    end

    it "listing" do
      20.times { FactoryGirl.create(:failure) }
      visit "/admin/failures"
      expect(page).to have_selector("td", :text => "RuntimeError", :count => 15)
      click_link "next"
      expect(page).to have_selector("td", :text => "RuntimeError", :count => 5)
      expect(page).to have_no_link("next")
      expect(page).to have_link("prev")
    end

    it "details", js: true do
      FactoryGirl.create(:failure, details: "Woopsee!")
      visit "/admin/failures"
      click_link "Show failure details"
      expect(page).to have_selector("pre", :text => "Woopsee!")
    end

    it "simulation" do
      expect(Failure.count).to eq(0)
      expect { visit "/admin/failures/new" }.to raise_error("Simulated Failure")
      expect(Failure.count).to eq(1)
    end
  end

  describe "non-administrators" do
    it "cannot simulate" do
      %w[guest member reporter officer].each do |role|
        login(role) unless role == "guest"
        visit "/admin/failures/new"
        expect(page).to have_selector("span.alert", :text => /authoriz/i)
        expect(Failure.count).to eq(0)
      end
    end
  end
end
