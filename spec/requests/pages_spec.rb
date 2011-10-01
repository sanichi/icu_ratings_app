require 'spec_helper'

describe "Pages" do
  describe "contacts" do
    before(:each) do
      @members   = (1..4).map { |i| Factory(:user, role: "member") }
      @reporters = (1..3).map { |i| Factory(:user, role: "reporter") }
      @officers  = (1..2).map { |i| Factory(:user, role: "officer") }
      @admins    = (1..1).map { |i| Factory(:user, role: "admin") }
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

    it "admins substitute for officers if there are none of the later" do
      @officers.each { |officer| officer.delete }
      visit "/contacts"
      {
        "Rating Officer"        => 1,
        "Website Administrator" => 1,
      }.each_pair do |h, n|
        page.find("h3", text: h).find(:xpath, "following-sibling::ul").all("li").should have(n).items
      end
    end
  end
end
