require 'spec_helper'

describe "Download" do
  describe "guests and members" do
    before(:each) do
      @download = Factory(:download)
    end

    it "cannot create, update or view downloads" do
      [nil, "member"].each do |role|
        login_user(role) if role
        ["/downloads", "/downloads/new", "downloads/#{@download.id}", "/downloads/#{@download.id}/edit"].each do |path|
          visit path
          page.should have_selector("span.alert", text: /not authorized/i)
        end
      end
    end
  end

  describe "reporters" do
    before(:each) do
      login_user("reporter")
      @download = Factory(:download)
    end

    it "can view downloads" do
      ["/downloads", "downloads/#{@download.id}"].each do |path|
        visit path
        page.should have_no_selector("span.alert")
      end
    end

    it "cannot create or update downloads" do
      ["/downloads/new", "downloads/#{@download.id}/edit"].each do |path|
        visit path
        page.should have_selector("span.alert", text: /not authorized/i)
      end
    end

    it "are not offered edit or delete links" do
      visit "/downloads"
      page.should have_no_link("Edit Download")
      page.should have_no_link("Delete Download")
    end
  end

  describe "officers" do
    before(:each) do
      login_user("officer")
      @text = "#{Rails.root}/spec/files/download.txt"
      @image = "#{Rails.root}/spec/files/download.png"
    end

    it "can create, view, edit and delete downloads" do
      Download.count.should == 0
      visit "/downloads/new"
      page.should have_selector("head title", text: "New Download")
      page.attach_file "download[uploaded_file]", @text
      page.fill_in "Comment", with: "Test Text"
      page.click_button "Create"
      page.should have_selector("span.notice", text: /created/i)
      Download.count.should == 1
      download = Download.first
      download.comment.should == "Test Text"
      download.content_type.should == "text/plain"
      download.file_name.should == "download.txt"
      download.data.should == "Test Data\n"
      page.click_link "download.txt"
      page.driver.response.body.should == "Test Data\n"
      page.driver.response.headers["Content-Type"].should == "text/plain"
      visit "/downloads"
      click_link "Edit Download"
      page.should have_selector("head title", text: "Update Download")
      page.attach_file "download[uploaded_file]", @image
      page.fill_in "Comment", with: "Test Image"
      page.click_button "Update"
      page.should have_selector("span.notice", text: /updated/i)
      Download.count.should == 1
      download = Download.first
      download.comment.should == "Test Image"
      click_link "Edit Download"
      page.fill_in "Comment", with: "Rubbish"
      page.click_button "Cancel"
      download.reload
      page.click_link "download.png"
      page.driver.response.headers["Content-Type"].should == "image/png"
      visit "/downloads"
      click_link "Delete Download"
      Download.count.should == 0
    end
  end

  describe "paging" do
    before(:each) do
      login_user("reporter")
      (1..16).each { Factory(:download) }
      @xpath = '//a[contains(.,".txt") and starts-with(@href,"/downloads/")]'
    end

    it "link after 15 items" do
      visit "downloads"
      page.should have_xpath(@xpath, count: 15)
      page.click_link "next"
      page.should have_xpath(@xpath, count: 1)
      page.click_link "prev"
      page.should have_xpath(@xpath, count: 15)
    end
  end
end
