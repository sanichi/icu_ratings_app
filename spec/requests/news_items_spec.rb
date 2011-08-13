require 'spec_helper'

describe "NewsItem" do
  describe "officers" do
    before(:each) do
      @user = login_user("officer")
      @news = Factory(:news_item)
    end

    it "can create, edit and delete a news items" do
      visit "/news_items/new"
      page.should have_selector("head title", :text => "Create News Item")
      headline, story = "Latest News", "Latest Story"
      NewsItem.where(:headline => headline, :story => story).should have(0).items
      page.fill_in "Headline", :with => headline
      page.fill_in "Story", :with => story
      page.click_button "Create"
      page.should have_selector("head title", :text => "ICU Ratings News")
      page.should have_selector("span.notice", :text => /created/i)
      page.should have_selector("span", :text => headline)
      page.should have_selector("p", :text => story)
      NewsItem.where(:headline => headline, :story => story).should have(1).item
      page.click_link "Edit"
      page.should have_selector("head title", :text => "Update News Item")
      headline = "Old News"
      page.fill_in "Headline", :with => headline
      page.click_button "Update"
      page.should have_selector("span.notice", :text => /updated/i)
      page.should have_selector("span", :text => headline)
      NewsItem.where(:headline => headline, :story => story).should have(1).item
      page.click_link "Delete"
      page.should have_selector("head title", :text => "ICU Ratings News")
      NewsItem.where(:headline => headline, :story => story).should have(0).items
    end

    it "can edit and delete other's news items" do
      visit "/news_items/#{@news.id}/edit"
      headline, story = "Latest News", "Latest Story"
      page.fill_in "Headline", :with => headline
      page.fill_in "Story", :with => story
      page.click_button "Update"
      NewsItem.where(:headline => headline, :story => story).should have(1).item
      page.click_link "Delete"
      NewsItem.where(:headline => headline, :story => story).should have(0).items
    end
  end

  describe "reporters" do
    before(:each) do
      @user = login_user("reporter")
      @news = Factory(:news_item)
    end

    it "cannot edit other's news items" do
      visit "/news_items/#{@news.id}"
      page.should have_no_link "Edit"
      visit "/news_items/#{@news.id}/edit"
      page.should have_selector("span.alert", :text => /authoriz/i)
    end

    it "can create, edit and delete their own news items" do
      visit "/news_items/new"
      headline, story = "Reporter's Headline", "Reporter's Story"
      page.fill_in "Headline", :with => headline
      page.fill_in "Story", :with => story
      page.click_button "Create"
      NewsItem.where(:headline => headline, :story => story).should have(1).item
      page.click_link "Edit"
      page.click_button "Cancel"
      page.click_link "Delete"
      NewsItem.where(:headline => headline, :story => story).should have(0).items
    end
  end
  
  describe "members" do
    before(:each) do
      @user = login_user("member")
      @news = [ Factory(:news_item), Factory(:news_item, :user => @user) ]
    end

    it "cannot manage news, even their own" do
      visit "/news_items/new"
      page.should have_selector("span.alert", :text => /authoriz/i)
      visit "/news_items/#{@news.first.id}/edit"
      page.should have_selector("span.alert", :text => /authoriz/i)
      visit "/news_items/#{@news.last.id}/edit"
      page.should have_selector("span.alert", :text => /authoriz/i)
    end
  end

  describe "anyone" do
    before(:each) do
      @news = (1..3).map { |i| Factory(:news_item) }
    end

    it "can list and read news" do
      visit "/news_items"
      page.should have_selector("head title", :text => "ICU Ratings News")
      @news.each { |news| page.should have_link(news.headline) }
      visit "/news_items/#{@news.first.id}"
      page.should have_selector("head title", :text => "ICU Ratings News")
      page.should have_selector("span", :text => @news.first.headline)
      page.should have_no_link "Edit"
      page.should have_no_link "Delete"
    end

    it "cannot manage news" do
      visit "/news_items/#{@news.first.id}/edit"
      page.should have_selector("span.alert", :text => /authoriz/i)
      visit "/news_items/new"
      page.should have_selector("span.alert", :text => /authoriz/i)
    end
  end
end
