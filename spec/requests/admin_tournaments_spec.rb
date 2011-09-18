require 'spec_helper'

describe "Tournament" do
  describe "reporters" do
    before(:each) do
      @user = login_user("reporter")
      @file = "#{Rails.root}/spec/files/bunratty_masters_2011.txt"
    end

    it "can only edit their own tournaments and players" do
      Tournament.count.should == 0
      Player.count.should == 0
      visit "/admin/uploads/new"
      page.select "FIDE-Krause", :from => "upload_format"
      page.attach_file "file", @file
      page.click_button "Upload"
      Tournament.count.should == 1
      t = Tournament.find(:first)
      tpath = "/admin/tournaments/#{t.id}"
      visit tpath
      page.should have_selector("div span", :text => "Bunratty 2011")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit?tie_breaks=' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit?ranks=' and @data-remote='true']")
      Player.count.should == 34
      p = Player.find_by_last_name_and_first_name("Baburin", "Alexander")
      ppath = "/admin/players/#{p.id}"
      visit ppath
      page.should have_selector("div span", :text => /Alexander Baburin/)
      page.should have_selector(:xpath, "//a[@href='#{ppath}/edit' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/admin/results') and @data-remote='true']", :count => 6)
      login_user("reporter")
      visit tpath
      page.should have_selector("div span", :text => "Bunratty 2011")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'#{tpath}/edit')]")
      visit ppath
      page.should have_selector("div span", :text => /Alexander Baburin/)
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'#{ppath}/edit')]")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/admin/results')]")
    end
  end
end
