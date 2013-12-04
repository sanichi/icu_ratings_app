require 'spec_helper'

describe "Tournament" do
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
    page.fill_in "Tournament name", with: arg[:name] || "Tournament"
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

  describe "loading" do
    before(:each) do
      login("reporter")
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

    it "Krause with BOM" do
      test = "armstrong_2012_with_bom.tab"
      load_icu_players_for(test)
      load_tournament(test, ratings: "ICU")
      Tournament.count.should == 1
      tournament = Tournament.first
      tournament.name.should == "LCU Div 1 Armstrong Cup"
      tournament.status.should == "ok"
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

  describe "email notification" do
    before(:each) do
      @n = ActionMailer::Base.deliveries.size
      @t = Tournament.count
    end

    it "should get sent for a reporter" do
      login("reporter")
      load_tournament("isle_of_man_2007.csv")
      Tournament.count.should == @t + 1
      ActionMailer::Base.deliveries.size.should == @n + 1
    end

    it "should not get sent for an officer" do
      login("officer")
      load_tournament("isle_of_man_2007.csv")
      Tournament.count.should == @t + 1
      ActionMailer::Base.deliveries.size.should == @n
    end

    it "should not get sent for an admin" do
      login("admin")
      load_tournament("isle_of_man_2007.csv")
      Tournament.count.should == @t + 1
      ActionMailer::Base.deliveries.size.should == @n
    end
  end

  describe "listing" do
    before(:each) do
      u = FactoryGirl.create(:user, role: "reporter")
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

  describe "editing" do
    before(:each) do
      @user = login("reporter")
      @file = test_file_path("bunratty_masters_2011.tab")
    end

    it "reporters can edit their own tournaments and players, officers can change reporter" do
      Tournament.count.should == 0
      Player.count.should == 0
      visit "/admin/uploads/new"
      page.select "FIDE-Krause", from: "upload_format"
      page.attach_file "file", @file
      page.click_button "Upload"
      Tournament.count.should == 1
      t = Tournament.first
      tpath = "/admin/tournaments/#{t.id}"
      visit tpath
      page.should have_selector("div span", text: "Bunratty 2011")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit?tie_breaks=' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit?ranks=' and @data-remote='true']")
      page.should have_no_selector(:xpath, "//a[@href='#{tpath}/edit?reporter=']")
      Player.count.should == 40
      p = Player.find_by_last_name_and_first_name("Baburin", "Alexander")
      ppath = "/admin/players/#{p.id}"
      visit ppath
      page.should have_selector("div span", text: /Alexander Baburin/)
      page.should have_selector(:xpath, "//a[@href='#{ppath}/edit' and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      page.should have_selector(:xpath, "//a[starts-with(@href,'/admin/results') and @data-remote='true']", count: 6)
      login("reporter")
      visit tpath
      page.should have_selector("div span", text: "Bunratty 2011")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'#{tpath}/edit')]")
      visit ppath
      page.should have_selector("div span", text: /Alexander Baburin/)
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'#{ppath}/edit')]")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      page.should have_no_selector(:xpath, "//a[starts-with(@href,'/admin/results')]")
      login("officer")
      visit tpath
      page.should have_selector(:xpath, "//a[@href='#{tpath}/edit?reporter=' and @data-remote='true']")
    end
  end

  describe "removing players" do
    before(:each) do
      file = "junior_championships_plus.tab"
      load_icu_players_for(file)
      @user = login("reporter")
      @file = test_file_path(file)
    end

    def signature(t)
      t.reload.players.sort { |a,b| a.num <=> b.num }.map { |p| "#{p.num}|#{p.last_name}|#{p.rank}" }.join("||")
    end

    it "players without any results or with only byes can be removed", js: true do
      visit "/admin/uploads/new"
      page.select "FIDE-Krause", from: "File format"
      page.select "FIDE", from: "Ratings"
      page.attach_file "file", @file
      page.click_button "Upload"
      Tournament.count.should == 1
      t = Tournament.first
      tpath = "/admin/tournaments/#{t.id}"
      visit tpath
      page.should have_selector("div span", text: "U-19 All Ireland 2010")
      page.should have_selector(:xpath, "//th[.='Status']/following-sibling::td[.='OK']")
      t.players.count.should == 8
      signature(t).should == "1|Cafolla|7||2|Dunne|4||3|Flynn|2||4|Fox|8||5|Griffiths|1||6|Hulleman|3||7|Orr|5||8|Sulskis|6"
      Player.count.should == 8
      Result.count.should == 22

      p = t.players.where(last_name: "Cafolla").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Cafolla")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      page.should have_selector("div span", text: "U-19 All Ireland 2010")
      page.should have_selector("div.flash span.notice", text: "Deleted player Cafolla, Peter")
      page.should have_no_link("Cafolla, Peter")
      signature(t).should == "1|Dunne|4||2|Flynn|2||3|Fox|7||4|Griffiths|1||5|Hulleman|3||6|Orr|5||7|Sulskis|6"
      Player.count.should == 7
      Result.count.should == 18

      p = t.players.where(last_name: "Flynn").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Flynn")
      page.should have_no_link "Delete Player"

      p = t.players.where(last_name: "Fox").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Fox")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      page.should have_selector("div span", text: "U-19 All Ireland 2010")
      page.should have_selector("div.flash span.notice", text: "Deleted player Fox, Anthony")
      page.should have_no_link("Fox, Anthony")
      signature(t).should == "1|Dunne|4||2|Flynn|2||3|Griffiths|1||4|Hulleman|3||5|Orr|5||6|Sulskis|6"
      Player.count.should == 6
      Result.count.should == 17

      p = t.players.where(last_name: "Griffiths").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Griffiths")
      page.should have_no_link "Delete Player"

      p = t.players.where(last_name: "Hulleman").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Hulleman")
      page.should have_no_link "Delete Player"

      p = t.players.where(last_name: "Orr").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Orr")
      page.should have_no_link "Delete Player"

      p = t.players.where(last_name: "Sulskis").first
      visit "/admin/players/#{p.id}"
      page.should have_selector("div span", text: "Sulskis")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      page.should have_selector("div span", text: "U-19 All Ireland 2010")
      page.should have_selector("div.flash span.notice", text: "Deleted player Sulskis, Sarunas")
      page.should have_no_link("Sulskis, Sarunas")
      signature(t).should == "1|Dunne|4||2|Flynn|2||3|Griffiths|1||4|Hulleman|3||5|Orr|5"
      Player.count.should == 5
      Result.count.should == 17
    end
  end

  describe "queueing" do
    before(:each) do
      @stgid = "#show_stage"
      @bname = "Update Stage"

      # This button seems to need a bit of time to complete.
      @click = Proc.new do
        click_on @bname
        sleep 0.1
      end

      # This button seems to need a little bit more time to complete.
      @update = Proc.new do
        page.first(:xpath, "//button/span[.='Update']").click
        sleep 0.2
      end
    end

    describe "queing and unqueueing" do
      before(:each) do
        tests = %w[bunratty_masters_2011.tab isle_of_man_2007.csv junior_championships_u19_2010.txt]
        load_icu_players_for(tests)
        u = login("officer")
        @t = tests.inject([]) do |m, n|
          t = test_tournament(n, u.id)
          t.reset_status
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
        @update.call
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
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
        @update.call
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
        page.should have_selector(@stgid, text: "Queued")
        Tournament.where("rorder IS NOT NULL").count.should == 2
        @t.each { |t| t.reload }
        @t[1].stage.should == "queued"
        @t[0].rorder.should == 2
        @t[0].last_tournament.should == @t[1]
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should == @t[0]
        @t[2].rorder.should be_nil
        @t[2].last_tournament.should be_nil
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[2].id}"
        page.should have_selector(@stgid, text: "Initial")
        @click.call
        @update.call
        page.should have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
        page.should have_selector(@stgid, text: "Queued")
        Tournament.where("rorder IS NOT NULL").count.should == 3
        @t.each { |t| t.reload }
        @t[2].stage.should == "queued"
        @t[0].rorder.should == 3
        @t[0].last_tournament.should == @t[2]
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should == @t[2]
        @t[2].rorder.should == 2
        @t[2].last_tournament.should == @t[1]
        @t[2].next_tournament.should == @t[0]

        visit "/admin/tournaments/#{@t[0].id}"
        page.should have_selector(@stgid, text: "Queued")
        @click.call
        @update.call
        page.should have_selector(@stgid, text: "Ready")
        Tournament.where("rorder IS NOT NULL").count.should == 2
        @t.each { |t| t.reload }
        @t[0].stage.should == "ready"
        @t[0].rorder.should be_nil
        @t[0].last_tournament.should be_nil
        @t[0].next_tournament.should be_nil
        @t[1].rorder.should == 1
        @t[1].last_tournament.should be_nil
        @t[1].next_tournament.should == @t[2]
        @t[2].rorder.should == 2
        @t[2].last_tournament.should == @t[1]
        @t[2].next_tournament.should be_nil

        visit "/admin/tournaments/#{@t[1].id}"
        page.should have_selector(@stgid, text: "Queued")
        @click.call
        @update.call
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
        @update.call
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
        @t.reset_status
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
            @update.call
            page.should have_selector(@stgid, text: "Queued")
            @t.reload.stage.should == "queued"
            @click.call
            @update.call
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

  describe "locking" do
    before(:each) do
      @r = login("reporter")
      @o = FactoryGirl.create(:user, role: "officer")
      @a = FactoryGirl.create(:user, role: "admin")
      @t = test_tournament("bunratty_masters_2011.tab", @r.id)
    end

    it "should be able to make modifications if tournament is not locked" do
      visit "/admin/tournaments/#{@t.id}"
      page.should have_link("Edit Tournament")
      page.should have_no_link("Tournament locked")
      page.should have_no_link("Tournament unlocked")
      visit "/admin/players/#{@t.players.first.id}"
      page.should have_link("Update Player")
      page.should have_link("Edit Result")
      login @o
      visit "/admin/tournaments/#{@t.id}"
      page.should have_link("Edit Tournament")
      page.should have_link("Tournament unlocked")
      login @a
      visit "/admin/tournaments/#{@t.id}"
      page.should have_link("Edit Tournament")
      page.should have_link("Tournament unlocked")
    end

    it "should not be able to make modifications if tournament is locked" do
      @t.update_column(:locked, true)
      visit "/admin/tournaments/#{@t.id}"
      page.should have_no_link("Edit Tournament")
      page.should have_no_link("Tournament locked")
      page.should have_no_link("Tournament unlocked")
      visit "/admin/players/#{@t.players.first.id}"
      page.should have_no_link("Update Player")
      page.should have_no_link("Edit Result")
      login @o
      visit "/admin/tournaments/#{@t.id}"
      page.should have_no_link("Edit Tournament")
      page.should have_link("Tournament locked")
      login @a
      visit "/admin/tournaments/#{@t.id}"
      page.should have_no_link("Edit Tournament")
      page.should have_link("Tournament locked")
    end
  end

  describe "rating run" do
    before(:each) do
      tests = %w[isle_of_man_2007.csv junior_championships_u19_2010.txt kilbunny_masters_2011.tab]
      load_icu_players_for(tests)
      load_old_ratings
      @subs = [159, 456, 1350, 6897].map do |icu_id| # add some subs to enable live ratings (choose players in tournaments.yml)
        FactoryGirl.create(:subscription, icu_id: icu_id, season: nil, category: "lifetime", pay_date: nil)
      end
      @u = login("officer")
      @t1, @t2, @t3 = tests.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t
      end
      @lnk = "Rate All"
      File.unlink(RatingRun.flag) if File.exists?(RatingRun.flag)
    end

    it "should be available for the next for rating (unless it's the last)" do
      LiveRating.unscoped.count.should == 0
      Tournament.next_for_rating.should == @t1
      visit "/admin/tournaments/#{@t1.id}"
      page.should have_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t1.id}"
      page.first(:link, "Rate").click
      LiveRating.unscoped.count.should == 0
      Tournament.next_for_rating.should == @t2
      visit "/admin/tournaments/#{@t1.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.should have_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.first(:link, "Rate").click
      LiveRating.unscoped.count.should == 0
      Tournament.next_for_rating.should == @t3
      visit "/admin/tournaments/#{@t1.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      page.should have_no_link(@lnk)          # not when it's the last tournament for rating
      page.first(:link, "Rate").click         # but it still has the Rate button (for rating one tournament)
      LiveRating.unscoped.count.should == @subs.size
      visit "/admin/tournaments/#{@t1.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.should have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      page.should have_no_link(@lnk)
    end

    it "should rate all tournaments" do
      visit "/admin/tournaments/#{@t1.id}"
      page.click_link @lnk
      RatingRun.count.should == 1
      rr = RatingRun.first
      rr.start_tournament.should == @t1
      rr.last_tournament.should == @t3
      rr.start_tournament_name.should == @t1.name_with_year
      rr.last_tournament_name.should == @t3.name_with_year
      rr.start_tournament_rorder.should == @t1.rorder
      rr.last_tournament_rorder.should == @t3.rorder
      rr.user.should == @u
      rr.status.should == "waiting"
      data = ""
      lambda { File.open(RatingRun.flag) { |f| data = f.read } }.should_not raise_error
      data.should == rr.id.to_s
      LiveRating.unscoped.count.should == 0
      rr.process
      LiveRating.unscoped.count.should == @subs.size
    end
  end
end
