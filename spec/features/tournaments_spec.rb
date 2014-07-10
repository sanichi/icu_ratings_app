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
      expect(Tournament.count).to eq(1)
      tournament = Tournament.first
      expect(tournament.name).to eq("Rathmines Senior 2011")
      expect(tournament.status).to_not eq("ok")
      expect(tournament.stage).to eq("initial")
    end

    it "SPExport" do
      name = "Test Tournament Name"
      load_tournament("junior_championships_u19_2010.txt", feds: "skip", name: name)
      expect(Tournament.count).to eq(1)
      tournament = Tournament.first
      expect(tournament.name).to eq(name)
      expect(tournament.status).to_not eq("ok")
      expect(tournament.stage).to eq("initial")
    end

    it "Krause" do
      load_tournament("bunratty_masters_2011.tab", ratings: "FIDE")
      expect(Tournament.count).to eq(1)
      tournament = Tournament.first
      expect(tournament.name).to eq("Bunratty 2011")
      expect(tournament.status).to_not eq("ok")
      expect(tournament.stage).to eq("initial")
    end

    it "Krause with BOM" do
      test = "armstrong_2012_with_bom.tab"
      load_icu_players_for(test)
      load_tournament(test, ratings: "ICU")
      expect(Tournament.count).to eq(1)
      tournament = Tournament.first
      expect(tournament.name).to eq("LCU Div 1 Armstrong Cup")
      expect(tournament.status).to eq("ok")
      expect(tournament.stage).to eq("initial")
    end

    it "CSV" do
      load_tournament("isle_of_man_2007.csv")
      expect(Tournament.count).to eq(1)
      tournament = Tournament.first
      expect(tournament.name).to eq("Isle of Man Masters, 2007")
      expect(tournament.status).to_not eq("ok")
      expect(tournament.stage).to eq("initial")
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
      expect(Tournament.count).to eq(@t + 1)
      expect(ActionMailer::Base.deliveries.size).to eq(@n + 1)
    end

    it "should not get sent for an officer" do
      login("officer")
      load_tournament("isle_of_man_2007.csv")
      expect(Tournament.count).to eq(@t + 1)
      expect(ActionMailer::Base.deliveries.size).to eq(@n)
    end

    it "should not get sent for an admin" do
      login("admin")
      load_tournament("isle_of_man_2007.csv")
      expect(Tournament.count).to eq(@t + 1)
      expect(ActionMailer::Base.deliveries.size).to eq(@n)
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
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t1.update_attribute(:status, "ok")
      visit "/tournaments"
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t2.update_attribute(:status, "ok")
      visit "/tournaments"
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
    end

    it "should not display tournaments at the 'initial' stage" do
      [@t1, @t2].each do |t|
        t.update_attribute(:status, "ok")
        t.update_attribute(:stage, "initial")
      end
      visit "/tournaments"
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t1.update_attribute(:stage, "ready")
      visit "/tournaments"
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_no_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
      @t2.update_attribute(:stage, "ready")
      visit "/tournaments"
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t1.id}']")
      expect(page).to have_selector(:xpath, "//a[@href='/tournaments/#{@t2.id}']")
    end
  end

  describe "editing" do
    before(:each) do
      @user = login("reporter")
      @file = test_file_path("bunratty_masters_2011.tab")
    end

    it "reporters can edit their own tournaments and players, officers can change reporter" do
      expect(Tournament.count).to eq(0)
      expect(Player.count).to eq(0)
      visit "/admin/uploads/new"
      page.select "FIDE-Krause", from: "upload_format"
      page.attach_file "file", @file
      page.click_button "Upload"
      expect(Tournament.count).to eq(1)
      t = Tournament.first
      tpath = "/admin/tournaments/#{t.id}"
      visit tpath
      expect(page).to have_selector("div span", text: "Bunratty 2011")
      expect(page).to have_selector(:xpath, "//a[@href='#{tpath}/edit' and @data-remote='true']")
      expect(page).to have_selector(:xpath, "//a[@href='#{tpath}/edit?tie_breaks=' and @data-remote='true']")
      expect(page).to have_selector(:xpath, "//a[@href='#{tpath}/edit?ranks=' and @data-remote='true']")
      expect(page).to have_no_selector(:xpath, "//a[@href='#{tpath}/edit?reporter=']")
      expect(Player.count).to eq(40)
      p = Player.find_by_last_name_and_first_name("Baburin", "Alexander")
      ppath = "/admin/players/#{p.id}"
      visit ppath
      expect(page).to have_selector("div span", text: /Alexander Baburin/)
      expect(page).to have_selector(:xpath, "//a[@href='#{ppath}/edit' and @data-remote='true']")
      expect(page).to have_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      expect(page).to have_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      expect(page).to have_selector(:xpath, "//a[starts-with(@href,'/admin/results') and @data-remote='true']", count: 6)
      login("reporter")
      visit tpath
      expect(page).to have_selector("div span", text: "Bunratty 2011")
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'#{tpath}/edit')]")
      visit ppath
      expect(page).to have_selector("div span", text: /Alexander Baburin/)
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'#{ppath}/edit')]")
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'/icu_players') and @data-remote='true']")
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'/fide_players') and @data-remote='true']")
      expect(page).to have_no_selector(:xpath, "//a[starts-with(@href,'/admin/results')]")
      login("officer")
      visit tpath
      expect(page).to have_selector(:xpath, "//a[@href='#{tpath}/edit?reporter=' and @data-remote='true']")
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
      expect(Tournament.count).to eq(1)
      t = Tournament.first
      tpath = "/admin/tournaments/#{t.id}"
      visit tpath
      expect(page).to have_selector("div span", text: "U-19 All Ireland 2010")
      expect(page).to have_selector(:xpath, "//th[.='Status']/following-sibling::td[.='OK']")
      expect(t.players.count).to eq(8)
      expect(signature(t)).to eq("1|Cafolla|7||2|Dunne|4||3|Flynn|2||4|Fox|8||5|Griffiths|1||6|Hulleman|3||7|Orr|5||8|Sulskis|6")
      expect(Player.count).to eq(8)
      expect(Result.count).to eq(22)

      p = t.players.where(last_name: "Cafolla").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Cafolla")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_selector("div span", text: "U-19 All Ireland 2010")
      expect(page).to have_selector("div.flash span.notice", text: "Deleted player Cafolla, Peter")
      expect(page).to have_no_link("Cafolla, Peter")
      expect(signature(t)).to eq("1|Dunne|4||2|Flynn|2||3|Fox|7||4|Griffiths|1||5|Hulleman|3||6|Orr|5||7|Sulskis|6")
      expect(Player.count).to eq(7)
      expect(Result.count).to eq(18)

      p = t.players.where(last_name: "Flynn").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Flynn")
      expect(page).to have_no_link "Delete Player"

      p = t.players.where(last_name: "Fox").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Fox")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_selector("div span", text: "U-19 All Ireland 2010")
      expect(page).to have_selector("div.flash span.notice", text: "Deleted player Fox, Anthony")
      expect(page).to have_no_link("Fox, Anthony")
      expect(signature(t)).to eq("1|Dunne|4||2|Flynn|2||3|Griffiths|1||4|Hulleman|3||5|Orr|5||6|Sulskis|6")
      expect(Player.count).to eq(6)
      expect(Result.count).to eq(17)

      p = t.players.where(last_name: "Griffiths").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Griffiths")
      expect(page).to have_no_link "Delete Player"

      p = t.players.where(last_name: "Hulleman").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Hulleman")
      expect(page).to have_no_link "Delete Player"

      p = t.players.where(last_name: "Orr").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Orr")
      expect(page).to have_no_link "Delete Player"

      p = t.players.where(last_name: "Sulskis").first
      visit "/admin/players/#{p.id}"
      expect(page).to have_selector("div span", text: "Sulskis")
      page.click_link "Delete Player"
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_selector("div span", text: "U-19 All Ireland 2010")
      expect(page).to have_selector("div.flash span.notice", text: "Deleted player Sulskis, Sarunas")
      expect(page).to have_no_link("Sulskis, Sarunas")
      expect(signature(t)).to eq("1|Dunne|4||2|Flynn|2||3|Griffiths|1||4|Hulleman|3||5|Orr|5")
      expect(Player.count).to eq(5)
      expect(Result.count).to eq(17)
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
        expect(Tournament.count).to eq(3)
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(0)
        @t.each do |t|
          expect(t.status).to eq("ok")
          expect(t.stage).to eq("initial")
          expect(t.rorder).to be_nil
        end
        expect(@t[0].start.to_s).to eq("2011-02-25")
        expect(@t[1].start.to_s).to eq("2007-09-22")
        expect(@t[2].start.to_s).to eq("2010-04-11")

        visit "/admin/tournaments/#{@t[0].id}"
        expect(page).to have_selector(@stgid, text: "Initial")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
        expect(page).to have_selector(@stgid, text: "Queued")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(1)
        @t.each { |t| t.reload }
        expect(@t[0].stage).to eq("queued")
        expect(@t[0].rorder).to eq(1)
        expect(@t[0].last_tournament).to be_nil
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to be_nil
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to be_nil
        expect(@t[2].rorder).to be_nil
        expect(@t[2].last_tournament).to be_nil
        expect(@t[2].next_tournament).to be_nil

        visit "/admin/tournaments/#{@t[1].id}"
        expect(page).to have_selector(@stgid, text: "Initial")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
        expect(page).to have_selector(@stgid, text: "Queued")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(2)
        @t.each { |t| t.reload }
        expect(@t[1].stage).to eq("queued")
        expect(@t[0].rorder).to eq(2)
        expect(@t[0].last_tournament).to eq(@t[1])
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to eq(1)
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to eq(@t[0])
        expect(@t[2].rorder).to be_nil
        expect(@t[2].last_tournament).to be_nil
        expect(@t[2].next_tournament).to be_nil

        visit "/admin/tournaments/#{@t[2].id}"
        expect(page).to have_selector(@stgid, text: "Initial")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        @click.call
        select "Queued", from: "tournament_stage"
        @update.call
        expect(page).to have_selector(@stgid, text: "Queued")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(3)
        @t.each { |t| t.reload }
        expect(@t[2].stage).to eq("queued")
        expect(@t[0].rorder).to eq(3)
        expect(@t[0].last_tournament).to eq(@t[2])
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to eq(1)
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to eq(@t[2])
        expect(@t[2].rorder).to eq(2)
        expect(@t[2].last_tournament).to eq(@t[1])
        expect(@t[2].next_tournament).to eq(@t[0])

        visit "/admin/tournaments/#{@t[0].id}"
        expect(page).to have_selector(@stgid, text: "Queued")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(2)
        @t.each { |t| t.reload }
        expect(@t[0].stage).to eq("ready")
        expect(@t[0].rorder).to be_nil
        expect(@t[0].last_tournament).to be_nil
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to eq(1)
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to eq(@t[2])
        expect(@t[2].rorder).to eq(2)
        expect(@t[2].last_tournament).to eq(@t[1])
        expect(@t[2].next_tournament).to be_nil

        visit "/admin/tournaments/#{@t[1].id}"
        expect(page).to have_selector(@stgid, text: "Queued")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(1)
        @t.each { |t| t.reload }
        expect(@t[1].stage).to eq("ready")
        expect(@t[0].rorder).to be_nil
        expect(@t[0].last_tournament).to be_nil
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to be_nil
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to be_nil
        expect(@t[2].rorder).to eq(1)
        expect(@t[2].last_tournament).to be_nil
        expect(@t[2].next_tournament).to be_nil

        visit "/admin/tournaments/#{@t[2].id}"
        expect(page).to have_selector(@stgid, text: "Queued")
        @click.call
        @update.call
        expect(page).to have_selector(@stgid, text: "Ready")
        expect(Tournament.where("rorder IS NOT NULL").count).to eq(0)
        @t.each { |t| t.reload }
        expect(@t[2].stage).to eq("ready")
        expect(@t[0].rorder).to be_nil
        expect(@t[0].last_tournament).to be_nil
        expect(@t[0].next_tournament).to be_nil
        expect(@t[1].rorder).to be_nil
        expect(@t[1].last_tournament).to be_nil
        expect(@t[1].next_tournament).to be_nil
        expect(@t[2].rorder).to be_nil
        expect(@t[2].last_tournament).to be_nil
        expect(@t[2].next_tournament).to be_nil
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
          expect(@t.status).to eq("ok")
          expect(@t.stage).to eq("ready")

          login(role || @u)
          visit "/admin/tournaments/#{@t.id}"
          expect(page).to have_selector(@stgid, text: "Ready") unless role == "member" || role == "guest"

          if able
            @click.call
            expect(page).to have_selector(:xpath, "//select[@id='tournament_stage']")
            select "Queued", from: "tournament_stage"
            @update.call
            expect(page).to have_selector(@stgid, text: "Queued")
            expect(@t.reload.stage).to eq("queued")
            @click.call
            @update.call
            expect(page).to have_selector(@stgid, text: "Ready")
            expect(@t.reload.stage).to eq("ready")
          elsif !role # owning reporter
            @click.call
            expect(page).to have_no_selector(:xpath, "//select[@id='tournament_stage']") # because only choice is "Initial"
          else
            expect(page).to have_no_link(@bname)
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
        expect(@p1).to be > 0
        expect(@r1).to be > 0
        expect(Tournament.count).to eq(2)
        expect(Upload.count).to eq(2)
        expect(Player.count).to be > @p1
        expect(Result.count).to be > @r1
        visit "/admin/tournaments/#{@t2.id}"
        page.click_link("Delete")
        expect(Tournament.count).to eq(1)
        expect(Upload.count).to eq(1)
        expect(Player.count).to eq(@p1)
        expect(Result.count).to eq(@r1)
        visit "/admin/tournaments/#{@t1.id}"
        page.click_link("Delete")
        expect(Tournament.count).to eq(0)
        expect(Player.count).to eq(0)
        expect(Result.count).to eq(0)
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
          expect(Tournament.count).to eq(0)
        end
      end

      [["other reporter", "reporter"], ["member", "member"], ["guest", nil]].each do |label, role|
        it "not #{label}" do
          role ? login(role) : page.click_link("Log out")
          visit "/admin/tournaments/#{@t.id}"
          expect(page).to have_no_link("Delete")
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
      expect(page).to have_link("Edit Tournament")
      expect(page).to have_no_link("Tournament locked")
      expect(page).to have_no_link("Tournament unlocked")
      visit "/admin/players/#{@t.players.first.id}"
      expect(page).to have_link("Update Player")
      expect(page).to have_link("Edit Result")
      login @o
      visit "/admin/tournaments/#{@t.id}"
      expect(page).to have_link("Edit Tournament")
      expect(page).to have_link("Tournament unlocked")
      login @a
      visit "/admin/tournaments/#{@t.id}"
      expect(page).to have_link("Edit Tournament")
      expect(page).to have_link("Tournament unlocked")
    end

    it "should not be able to make modifications if tournament is locked" do
      @t.update_column(:locked, true)
      visit "/admin/tournaments/#{@t.id}"
      expect(page).to have_no_link("Edit Tournament")
      expect(page).to have_no_link("Tournament locked")
      expect(page).to have_no_link("Tournament unlocked")
      visit "/admin/players/#{@t.players.first.id}"
      expect(page).to have_no_link("Update Player")
      expect(page).to have_no_link("Edit Result")
      login @o
      visit "/admin/tournaments/#{@t.id}"
      expect(page).to have_no_link("Edit Tournament")
      expect(page).to have_link("Tournament locked")
      login @a
      visit "/admin/tournaments/#{@t.id}"
      expect(page).to have_no_link("Edit Tournament")
      expect(page).to have_link("Tournament locked")
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
      expect(LiveRating.unscoped.count).to eq(0)
      expect(Tournament.next_for_rating).to eq(@t1)
      visit "/admin/tournaments/#{@t1.id}"
      expect(page).to have_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t1.id}"
      page.first(:link, "Rate").click
      expect(LiveRating.unscoped.count).to eq(0)
      expect(Tournament.next_for_rating).to eq(@t2)
      visit "/admin/tournaments/#{@t1.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      expect(page).to have_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      page.first(:link, "Rate").click
      expect(LiveRating.unscoped.count).to eq(0)
      expect(Tournament.next_for_rating).to eq(@t3)
      visit "/admin/tournaments/#{@t1.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      expect(page).to have_no_link(@lnk)          # not when it's the last tournament for rating
      page.first(:link, "Rate").click         # but it still has the Rate button (for rating one tournament)
      expect(LiveRating.unscoped.count).to eq(@subs.size)
      visit "/admin/tournaments/#{@t1.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t2.id}"
      expect(page).to have_no_link(@lnk)
      visit "/admin/tournaments/#{@t3.id}"
      expect(page).to have_no_link(@lnk)
    end

    it "should rate all tournaments" do
      visit "/admin/tournaments/#{@t1.id}"
      page.click_link @lnk
      expect(RatingRun.count).to eq(1)
      rr = RatingRun.first
      expect(rr.start_tournament).to eq(@t1)
      expect(rr.last_tournament).to eq(@t3)
      expect(rr.start_tournament_name).to eq(@t1.name_with_year)
      expect(rr.last_tournament_name).to eq(@t3.name_with_year)
      expect(rr.start_tournament_rorder).to eq(@t1.rorder)
      expect(rr.last_tournament_rorder).to eq(@t3.rorder)
      expect(rr.user).to eq(@u)
      expect(rr.status).to eq("waiting")
      data = ""
      expect { File.open(RatingRun.flag) { |f| data = f.read } }.to_not raise_error
      expect(data).to eq(rr.id.to_s)
      expect(LiveRating.unscoped.count).to eq(0)
      rr.process
      expect(LiveRating.unscoped.count).to eq(@subs.size)
    end
  end
end
