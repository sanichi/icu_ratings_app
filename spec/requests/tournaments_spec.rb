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
      Tournament.order(:id).last
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
      tournament.stage.should == "initial"
    end

    it "SPExport" do
      name = "Test Tournament Name"
      load_tournament("junior_championships_u19_2010.txt", feds: "skip", name: name)
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == name
      tournament.status.should_not == "ok"
      tournament.stage.should == "initial"
    end

    it "Krause" do
      load_tournament("bunratty_masters_2011.tab", ratings: "FIDE")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "Bunratty 2011"
      tournament.status.should_not == "ok"
      tournament.stage.should == "initial"
    end

    it "CSV" do
      load_tournament("isle_of_man_2007.csv")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "Isle of Man Masters, 2007"
      tournament.status.should_not == "ok"
      tournament.stage.should == "initial"
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
        t.update_attribute(:stage, "ready")
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

    it "should not display tournaments at the 'initial' stage" do
      [@t1, @t2].each do |t|
        t.update_attribute(:status, "ok")
        t.update_attribute(:stage, "initial")
      end
      visit "/tournaments"
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t1.update_attribute(:stage, "ready")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t2.update_attribute(:stage, "ready")
      visit "/tournaments"
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      page.should have_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
    end
  end

  describe "queueing" do
    before(:each) do
      @bpath = "//button/span[.='Update']"
      @stgid = "#show_stage"
      @bname = "Update Stage"

      # One particular button seems to need a bit of time to complete.
      @click = Proc.new do
        click_on @bname
        sleep 0.1
      end
    end

    describe "queing and unqueueing" do
      before(:each) do
        tests = %w[bunratty_masters_2011.tab isle_of_man_2007.csv junior_championships_u19_2010.txt]
        load_icu_players_for(tests)
        u = login("officer")
        @t = tests.inject([]) do |m, n|
          t = test_tournament(n, u.id)
          t.check_status
          m.push(t)
        end
      end

      it "three tournaments", js: true do
        Tournament.count.should == 3
        Tournament.where("rorder IS NOT NULL").count.should == 0
        @t.each do |t|
          t.status.should == "ok"
          t.stage.should == "initial"
          t.rorder.should be_nil
        end
        @t[0].start.to_s.should == "2011-02-25"
        @t[1].start.to_s.should == "2007-09-22"
        @t[2].start.to_s.should == "2010-04-11"

        visit "/admin/tournaments/#{@t[0].id}"
        page.should have_selector(@stgid, text: "Initial")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Queued")
        Tournament.where("rorder IS NOT NULL").count.should == 1
        @t.each { |t| t.reload }
        @t[0].stage.should == "queued"
        @t[0].rorder.should == 1
        @t[0].last_tournament.should be_nil
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should be_nil
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should be_nil
        @t[2].rorder.should be_nil
        @t[2].last_tournament.should be_nil
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[1].id}"
        page.should have_selector(@stgid, text: "Initial")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Queued")
        Tournament.where("rorder IS NOT NULL").count.should == 2
        @t.each { |t| t.reload }
        @t[1].stage.should == "queued"
        @t[0].rorder.should == 2
        @t[0].last_tournament.should_not be_nil
        @t[0].last_tournament.id.should == @t[1].id
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should_not be_nil
        @t[1].next_tournament.id.should == @t[0].id
        @t[2].rorder.should be_nil
        @t[2].last_tournament.should be_nil
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[2].id}"
        page.should have_selector(@stgid, text: "Initial")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Queued")
        Tournament.where("rorder IS NOT NULL").count.should == 3
        @t.each { |t| t.reload }
        @t[2].stage.should == "queued"
        @t[0].rorder.should == 3
        @t[0].last_tournament.should_not be_nil
        @t[0].last_tournament.id.should == @t[2].id
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should_not be_nil
        @t[1].next_tournament.id.should == @t[2].id
        @t[2].rorder.should == 2
        @t[2].last_tournament.should_not be_nil
        @t[2].last_tournament.id.should == @t[1].id
        @t[2].next_tournament.should_not be_nil
        @t[2].next_tournament.id.should == @t[0].id

        visit "/admin/tournaments/#{@t[0].id}"
        page.should have_selector(@stgid, text: "Queued")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        Tournament.where("rorder IS NOT NULL").count.should == 2
        @t.each { |t| t.reload }
        @t[0].stage.should == "ready"
        @t[0].rorder.should be_nil
        @t[0].last_tournament.should be_nil
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should_not be_nil
        @t[1].next_tournament.id.should == @t[2].id
        @t[2].rorder.should == 2
        @t[2].last_tournament.should_not be_nil
        @t[2].last_tournament.id.should == @t[1].id
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[1].id}"
        page.should have_selector(@stgid, text: "Queued")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        Tournament.where("rorder IS NOT NULL").count.should == 1
        @t.each { |t| t.reload }
        @t[1].stage.should == "ready"
        @t[0].rorder.should be_nil
        @t[0].last_tournament.should be_nil
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should be_nil
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should be_nil
        @t[2].rorder.should == 1
        @t[2].last_tournament.should be_nil
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[2].id}"
        page.should have_selector(@stgid, text: "Queued")
        @click.call
        page.find(:xpath, @bpath).click
        page.should have_selector(@stgid, text: "Ready")
        Tournament.where("rorder IS NOT NULL").count.should == 0
        @t.each { |t| t.reload }
        @t[2].stage.should == "ready"
        @t[0].rorder.should be_nil
        @t[0].last_tournament.should be_nil
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should be_nil
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should be_nil
        @t[2].rorder.should be_nil
        @t[2].last_tournament.should be_nil
        @t[2].next_tournament.should be_nil
      end
    end

    describe "authorization" do
      before(:each) do
        test = "junior_championships_u19_2010.txt"
        load_icu_players_for(test)
        @u = login("reporter")
        @t = test_tournament(test, @u.id)
        @t.check_status
        @t.update_attribute(:stage, "ready")
      end

      [["admin", true], ["officer", true], ["reporter", false], [nil, false], ["member", false], ["guest", false]].each do |role, able|
        it "#{role || 'owning reporter'} #{able ? 'can' : 'can not'}", js: true do
          @t.status.should == "ok"
          @t.stage.should == "ready"

          login(role || @u)
          visit "/admin/tournaments/#{@t.id}"
          page.should have_selector(@stgid, text: "Ready") unless role == "member" || role == "guest"

          if able
            @click.call
            page.should have_selector(:xpath, "//select[@id='tournament_stage']")
            select "Queued", from: "tournament_stage"
            page.find(:xpath, @bpath).click
            page.should have_selector(@stgid, text: "Queued")
            @t.reload.stage.should == "queued"
            @click.call
            page.find(:xpath, @bpath).click
            page.should have_selector(@stgid, text: "Ready")
            @t.reload.stage.should == "ready"
          elsif !role # owning reporter
            @click.call
            page.should have_no_selector(:xpath, "//select[@id='tournament_stage']") # because only choice is "Initial"
          else
            page.should have_no_link(@bname)
          end
        end
      end
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
