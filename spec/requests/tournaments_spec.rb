require 'spec_helper'

describe "Tournament" do
  describe "loading" do
    before(:each) do
      login("reporter")
    end

    def load_tournament(file, arg={})
      visit "/admin/uploads/new"
      set_upload_format(page, file)
      set_tournament_name(page, file, arg)
      set_start_date(page, file, arg)
      set_feds_option(page, file, arg)
      set_ratings_option(page, file, arg)
      page.attach_file "file", test_file_path(file)
      page.click_button "Upload"
      Tournament.unscoped.order(:id).last
    end

    def set_upload_format(page, file)
      value = case file
        when /\.csv$/ then "ICU-CSV"
        when /\.tab$/ then "FIDE-Krause"
        when /\.txt$/ then "Swiss Perfect Export"
        when /\.zip$/ then "Swiss Perfect"
      end
      page.select value, from: "upload_format"
    end

    def set_start_date(page, file, arg)
      return unless file =~ /\.(txt|zip)/
      page.fill_in "start", with: arg[:start] || "2011-03-06"
    end

    def set_tournament_name(page, file, arg)
      return unless file =~ /\.(txt)/
      page.fill_in "name", with: arg[:name] || "Tournament"
    end

    def set_feds_option(page, file, arg)
      return unless file =~ /\.(tab|txt|zip)/
      value = case arg[:feds]
        when "skip"   then "Skip if invalid"
        when "ignore" then "Ignore all"
        else "Error if invalid"
      end
      page.select value, from: "feds"
    end

    def set_ratings_option(page, file, arg)
      return unless file =~ /\.(tab)/
      value = case arg[:ratings]
        when "ICU"   then "ICU"
        when "FIDE"  then "FIDE"
        else ""
      end
      page.select value, from: "ratings"
    end

    it "SwissPerfect" do
      load_tournament("rathmines_senior_2011.zip", feds: "ignore")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "Rathmines Senior 2011"
      tournament.status.should_not == "ok"
      tournament.stage.should == "scratch"
    end

    it "SPExport" do
      name = "Test Tournament Name"
      load_tournament("junior_championships_u19_2010.txt", feds: "skip", name: name)
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == name
      tournament.status.should_not == "ok"
      tournament.stage.should == "scratch"
    end

    it "Krause" do
      load_tournament("bunratty_masters_2011.tab", ratings: "FIDE")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "Bunratty 2011"
      tournament.status.should_not == "ok"
      tournament.stage.should == "scratch"
    end

    it "CSV" do
      load_tournament("isle_of_man_2007.csv")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "Isle of Man Masters, 2007"
      tournament.status.should_not == "ok"
      tournament.stage.should == "scratch"
    end
  end

  describe "listing" do
    before(:each) do
      u = Factory(:user, role: "reporter")
      @t1 = test_tournament("bunratty_masters_2011.tab", u.id)
      @t2 = test_tournament("junior_championships_u19_2010.txt", u.id)
    end
    
    it "should not display tournaments whose status is not 'ok'" do
      [@t1, @t2].each do |t|
        t.update_attribute(:status, "problem")
        t.update_attribute(:stage, "unrated")
      end
      visit "/tournaments"
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t1.update_attribute(:status, "ok")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t2.update_attribute(:status, "ok")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
    end

    it "should not display tournaments at the 'scratch' stage" do
      [@t1, @t2].each do |t|
        t.update_attribute(:status, "ok")
        t.update_attribute(:stage, "scratch")
      end
      visit "/tournaments"
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t1.update_attribute(:stage, "unrated")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t2.update_attribute(:stage, "unrated")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
    end
  end

  describe "deleting" do
    describe "cascades" do
      before(:each) do
        u = login("reporter")
        @t1 = test_tournament("bunratty_masters_2011.tab", u.id)
        @p1 = Player.count
        @r1 = Result.count
        @t2 = test_tournament("junior_championships_u19_2010.txt", u.id)
      end

      it "uploads, players and results" do
        @p1.should be > 0
        @r1.should be > 0
        Tournament.count.should == 2
        Upload.count.should == 2
        Player.count.should be > @p1
        Result.count.should be > @r1
        visit "/admin/tournaments/#{@t2.id}"
        page.click_link("Delete")
        Tournament.count.should == 1
        Upload.count.should == 1
        Player.count.should == @p1
        Result.count.should == @r1
        visit "/admin/tournaments/#{@t1.id}"
        page.click_link("Delete")
        Tournament.count.should == 0
        Player.count.should == 0
        Result.count.should == 0
      end
    end

    describe "can" do
      before(:each) do
        @u = login("reporter")
        @t = test_tournament("junior_championships_u19_2010.txt", @u.id)
      end

      [["admin", "admin"], ["officer", "officer"], ["owning reporter", nil]].each do |label, role|
        it label do
          login(role || @u)
          visit "/admin/tournaments/#{@t.id}"
          page.click_link("Delete")
          Tournament.count.should == 0
        end
      end

      [["other reporter", "reporter"], ["member", "member"], ["guest", nil]].each do |label, role|
        it "not #{label}" do
          role ? login(role) : page.click_link("Log out")
          visit "/admin/tournaments/#{@t.id}"
          page.should have_no_link("Delete")
        end
      end
    end
  end
end
