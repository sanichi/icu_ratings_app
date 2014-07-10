require 'spec_helper'

describe "Download" do
  describe "guests and members" do
    before(:each) do
      @download = FactoryGirl.create(:download)
    end

    it "cannot create, update or view downloads" do
      [nil, "member"].each do |role|
        login(role) if role
        ["/downloads", "/downloads/new", "downloads/#{@download.id}", "/downloads/#{@download.id}/edit"].each do |path|
          visit path
          expect(page).to have_selector("span.alert", text: /not authorized/i)
        end
      end
    end
  end

  describe "reporters" do
    before(:each) do
      login("reporter")
      @download = FactoryGirl.create(:download)
    end

    it "can view downloads" do
      ["/downloads", "downloads/#{@download.id}"].each do |path|
        visit path
        expect(page).to have_no_selector("span.alert")
      end
    end

    it "cannot create or update downloads" do
      ["/downloads/new", "downloads/#{@download.id}/edit"].each do |path|
        visit path
        expect(page).to have_selector("span.alert", text: /not authorized/i)
      end
    end

    it "are not offered edit or delete links" do
      visit "/downloads"
      expect(page).to have_no_link("Edit Download")
      expect(page).to have_no_link("Delete Download")
    end
  end

  describe "officers" do
    before(:each) do
      login("officer")
      @text = test_file_path("download.txt")
      @image = test_file_path("download.png")
    end

    it "can create, view, edit and delete downloads" do
      expect(Download.count).to eq(0)
      visit "/downloads/new"
      expect(page).to have_title("New Download")
      page.attach_file "download[uploaded_file]", @text
      page.fill_in "Comment", with: "Test Text"
      page.click_button "Create"
      expect(page).to have_selector("span.notice", text: /created/i)
      expect(Download.count).to eq(1)
      download = Download.first
      expect(download.comment).to eq("Test Text")
      expect(download.content_type).to eq("text/plain")
      expect(download.file_name).to eq("download.txt")
      expect(download.data).to eq("Test Data\n")
      page.click_link "download.txt"
      expect(page.driver.response.body).to eq("Test Data\n")
      expect(page.driver.response.headers["Content-Type"]).to eq("text/plain")
      visit "/downloads"
      click_link "Edit Download"
      expect(page).to have_title("Update Download")
      page.attach_file "download[uploaded_file]", @image
      page.fill_in "Comment", with: "Test Image"
      page.click_button "Update"
      expect(page).to have_selector("span.notice", text: /updated/i)
      expect(Download.count).to eq(1)
      download = Download.first
      expect(download.comment).to eq("Test Image")
      click_link "Edit Download"
      page.fill_in "Comment", with: "Rubbish"
      page.click_button "Cancel"
      download.reload
      page.click_link "download.png"
      expect(page.driver.response.headers["Content-Type"]).to eq("image/png")
      visit "/downloads"
      click_link "Delete Download"
      expect(Download.count).to eq(0)
    end
  end

  describe "paging" do
    before(:each) do
      login("reporter")
      (1..16).each { FactoryGirl.create(:download) }
      @xpath = '//a[contains(.,".txt") and starts-with(@href,"/downloads/")]'
    end

    it "link after 15 items" do
      visit "downloads"
      expect(page).to have_xpath(@xpath, count: 15)
      page.click_link "next"
      expect(page).to have_xpath(@xpath, count: 1)
      page.click_link "prev"
      expect(page).to have_xpath(@xpath, count: 15)
    end
  end
end
