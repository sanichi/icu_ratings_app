require 'spec_helper'

describe "Upload" do
  describe "guests" do
    it "cannot upload files" do
      visit "/admin/uploads/new"
      page.should have_selector("span.alert", :text => /not authorized/i)
    end
  end

  describe "members" do
    it "cannot upload files" do
      login_user("member")
      visit "/admin/uploads/new"
      page.should have_selector("span.alert", :text => /not authorized/i)
    end
  end

  describe "invalid files" do
    describe "reporters" do
      before(:each) do
        @user = login_user("reporter")
        @file = "#{Rails.root}/spec/files/invalid.txt"
      end

      it "can upload and then delete" do
        Upload.count.should == 0
        visit "/admin/uploads/new"
        page.should have_selector("head title", :text => "File Upload")
        page.select "FIDE-Krause", :from => "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        page.should have_selector("span.alert", :text => /cannot extract/i)
        Upload.count.should == 1
        upload = Upload.first
        upload.error.should_not be_blank
        upload.tournament.should be_blank
        visit "/admin/uploads/#{upload.id}"
        page.should have_selector("head title", :text => "Upload")
        page.click_link("Delete")
        page.should have_selector("head title", :text => "Search Uploads")
        Upload.count.should == 0
      end

      it "cannot delete uploads they don't own" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", :from => "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        Upload.count.should == 1
        upload = Upload.first
        upload.user.should == @user
        @user = login_user("reporter")
        upload.user.should_not == @user
        visit "/admin/uploads/#{upload.id}"
        page.should_not have_link("Delete")
      end
    end

    describe "officers" do
      before(:each) do
        @user = login_user("officer")
        @file = "#{Rails.root}/spec/files/invalid.txt"
      end

      it "can delete uploads they don't own" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", :from => "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        Upload.count.should == 1
        upload = Upload.first
        upload.user.should == @user
        @user = login_user("officer")
        upload.user.should_not == @user
        visit "/admin/uploads/#{upload.id}"
        page.click_link("Delete")
        Upload.count.should == 0
      end
    end
  end
end
