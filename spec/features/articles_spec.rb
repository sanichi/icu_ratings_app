require 'spec_helper'

describe "Article" do
  describe "officer" do
    before(:each) do
      @user = login("officer")
      @article = FactoryGirl.create(:article)
    end

    it "can create, edit and delete an article" do
      visit "/articles/new"
      expect(page).to have_title("Create Article")
      headline, story = "Latest News", "Latest Story"
      expect(Article.where(headline: headline, story: story).count).to eq(0)
      page.fill_in "Headline", with: headline
      page.fill_in "Story", with: story
      page.click_button "Create"
      expect(page).to have_title(headline)
      expect(page).to have_selector("span.notice", text: /created/i)
      expect(page).to have_selector("span", text: headline)
      expect(page).to have_selector("p", text: story)
      expect(page).to have_link("Markdown")
      expect(Article.where(headline: headline, story: story).count).to eq(1)
      page.click_link "Edit"
      expect(page).to have_title("Update Article")
      headline = "Old News"
      page.fill_in "Headline", with: headline
      page.click_button "Update"
      expect(page).to have_selector("span.notice", text: /updated/i)
      expect(page).to have_selector("span", text: headline)
      expect(Article.where(headline: headline, story: story).count).to eq(1)
      page.click_link "Delete"
      expect(page).to have_title("Articles")
      expect(Article.where(headline: headline, story: story).count).to eq(0)
    end

    it "can edit and delete other's articles" do
      visit "/articles/#{@article.id}/edit"
      headline, story = "Latest News", "Latest Story"
      page.fill_in "Headline", with: headline
      page.fill_in "Story", with: story
      page.click_button "Update"
      expect(Article.where(headline: headline, story: story).count).to eq(1)
      page.click_link "Delete"
      expect(Article.where(headline: headline, story: story).count).to eq(0)
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
        expect(page).to have_selector("span.alert", text: /authoriz/i)
        visit "/articles/#{@article.first.id}/edit"
        expect(page).to have_selector("span.alert", text: /authoriz/i)
        visit "/articles/#{@article.last.id}/edit"
        expect(page).to have_selector("span.alert", text: /authoriz/i)
      end

      it "does not have a link to see Markdown" do
        visit "/articles/#{@article.first.id}"
        expect(page).to have_no_link("Markdown")
        visit "/articles/#{@article.last.id}"
        expect(page).to have_no_link("Markdown")
      end
    end
  end

  describe "anyone" do
    before(:each) do
      @article = (1..3).map { |i| FactoryGirl.create(:article) }
    end

    it "can list and read articles" do
      visit "/articles"
      expect(page).to have_title("Articles")
      @article.each { |article| expect(page).to have_link(article.headline) }
      visit "/articles/#{@article.first.id}"
      expect(page).to have_title(@article.first.headline)
      expect(page).to have_selector("span", text: @article.first.headline)
      expect(page).to have_no_link "Edit"
      expect(page).to have_no_link "Delete"
      expect(page).to have_no_link "Markdown"
    end

    it "cannot manage articles" do
      visit "/articles/#{@article.first.id}/edit"
      expect(page).to have_selector("span.alert", text: /authoriz/i)
      visit "/articles/new"
      expect(page).to have_selector("span.alert", text: /authoriz/i)
    end
  end

  describe "home_page" do
    before(:each) do
      @article = (1..3).map { |i| FactoryGirl.create(:article, published: false) }
    end

    it "has only published items" do
      visit "/home"
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'/articles/')]")
      @article.each { |n| n.update_attribute(:published, true) }
      visit "/home"
      expect(page).to have_selector(:xpath, "//a[starts-with(@href,'/articles/')]", count: @article.size)
    end
  end
end
