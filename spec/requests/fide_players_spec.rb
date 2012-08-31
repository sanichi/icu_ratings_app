require 'spec_helper'

# Note: these tests are a little fragile because of the need to wait occasionally,
# to allow things to synchronize. It would be better to find a way to avoid that.

describe FidePlayer do
  describe "update ICU ID", js: true do
    before(:each) do
      @i = FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-09-11", title: "IM", gender: "M")
      @f = FactoryGirl.create(:fide_player, id: 250035, last_name: "Orr", first_name: "Mark", fed: "IRL", born: 1955, title: "IM", gender: "M", icu_player: nil)
      @link = "Link FIDE player to this ICU player"
      @unlink = "Unlink FIDE player from this ICU player"
      login("admin")
      visit fide_players_path
      page.click_link "?"
      sleep 0.1
    end

    it "create a link bewteen a FIDE and ICU player then destroy it" do
      @f.icu_id.should be_nil
      page.click_link @link
      sleep 0.1
      @f.reload
      @f.icu_id.should == @i.id
      page.click_link @i.id.to_s
      page.click_link @unlink
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should not create a link if federation is mismatched" do
      @i.update_column(:fed, "SCO")
      page.click_link @link
      page.driver.browser.switch_to.alert.dismiss
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should not create a link if title is mismatched" do
      @i.update_column(:title, "GM")
      page.click_link @link
      page.driver.browser.switch_to.alert.dismiss
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should not create a link if YOB/DOB is mismatched" do
      @i.update_column(:dob, "1986-06-16")
      page.click_link @link
      page.driver.browser.switch_to.alert.dismiss
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should not create a link if gender is mismatched" do
      @i.update_column(:gender, "F")
      page.click_link @link
      page.driver.browser.switch_to.alert.dismiss
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should not create a link if both names are mismatched" do
      @i.update_column(:first_name, "Malcolm")
      @i.update_column(:last_name, "Algeo")
      page.click_link @link
      page.driver.browser.switch_to.alert.dismiss
      sleep 0.1
      @f.reload
      @f.icu_id.should be_nil
    end

    it "should create a link if only one name is mismatched" do
      @i.update_column(:first_name, "Malcolm")
      page.click_link @link
      sleep 0.1
      @f.reload
      @f.icu_id.should == @i.id
    end
  end
end
