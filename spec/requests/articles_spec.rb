require 'spec_helper'

describe "Article" do
  describe "officer" do
    before(:each) do
      @user = login("officer")
      @article = FactoryGirl.create(:article)
    end

    it "can create, edit and delete an article" do
      visit "/articles/new"
      page.should have_selector("head title", text: "Create Article")
      headline, story = "Latest News", "Latest Story"
      Article.where(headline: headline, story: story).should have(0).items
      page.fill_in "Headline", with: headline
      page.fill_in "Story", with: story
      page.click_button "Create"
      page.should have_selector("head title", text: "Article")
      page.should have_selector("span.notice", text: /created/i)
      page.should have_selector("span", text: headline)
      page.should have_selector("p", text: story)
      page.should have_link("Markdown")
      Article.where(headline: headline, story: story).should have(1).item
      page.click_link "Edit"
      page.should have_selector("head title", text: "Update Article")
      headline = "Old News"
      page.fill_in "Headline", with: headline
      page.click_button "Update"
      page.should have_selector("span.notice", text: /updated/i)
      page.should have_selector("span", text: headline)
      Article.where(headline: headline, story: story).should have(1).item
      page.click_link "Delete"
      page.should have_selector("head title", text: "Article")
      Article.where(headline: headline, story: story).should have(0).items
    end

    it "can edit and delete other's articles" do
      visit "/articles/#{@article.id}/edit"
      page.should have_link("Markdown")
      headline, story = "Latest News", "Latest Story"
      page.fill_in "Headline", with: headline
      page.fill_in "Story", with: story
      page.click_button "Update"
      Article.where(headline: headline, story: story).should have(1).item
      page.click_link "Delete"
      Article.where(headline: headline, story: story).should have(0).items
    end
  end

  %w[reporter member].each do |type|
    describe type do
      before(:each) do
        @user = login(type)
        @article = [ FactoryGirl.create(:article), FactoryGirl.create(:article, user: @user) ]
      end

      it "cannot manage articles, even their own" do
        visit "/articles/new"
        page.should have_selector("span.alert", text: /authoriz/i)
        visit "/articles/#{@article.first.id}/edit"
        page.should have_selector("span.alert", text: /authoriz/i)
        visit "/articles/#{@article.last.id}/edit"
        page.should have_selector("span.alert", text: /authoriz/i)
      end

      it "does not have a link to see Markdown" do
        visit "/articles/#{@article.first.id}"
        page.should have_no_link("Markdown")
        visit "/articles/#{@article.last.id}"
        page.should have_no_link("Markdown")
      end
    end
  end

  describe "anyone" do
    before(:each) do
      @article = (1..3).map { |i| FactoryGirl.create(:article) }
    end

    it "can list and read articles" do
      visit "/articles"
      page.should have_selector("head title", text: "Article")
      @article.each { |article| page.should have_link(article.headline) }
      visit "/articles/#{@article.first.id}"
      page.should have_selector("head title", text: "Article")
      page.should have_selector("span", text: @article.first.headline)
      page.should have_no_link "Edit"
      page.should have_no_link "Delete"
      page.should have_no_link "Markdown"
    end

    it "cannot manage articles" do
      visit "/articles/#{@article.first.id}/edit"
      page.should have_selector("span.alert", text: /authoriz/i)
      visit "/articles/new"
      page.should have_selector("span.alert", text: /authoriz/i)
    end
  end

  describe "home_page" do
    before(:each) do
      @article = (1..3).map { |i| FactoryGirl.create(:article, published: false) }
    end

    it "has only published items" do
      visit "/home"
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/articles/')]")
      @article.each { |n| n.update_attribute(:published, true) }
      visit "/home"
      page.should have_selector(:xpath, "//a[starts-with(@href,'/articles/')]", count: @article.size)
    end
  end
end
