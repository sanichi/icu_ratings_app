# encoding: UTF-8
require 'spec_helper'

describe "Upload" do
  describe "guests" do
    it "cannot upload files" do
      visit "/admin/uploads/new"
      expect(page).to have_selector("span.alert", text: /not authorized/i)
    end
  end

  describe "members" do
    it "cannot upload files" do
      login("member")
      visit "/admin/uploads/new"
      expect(page).to have_selector("span.alert", text: /not authorized/i)
    end
  end

  describe "invalid files" do
    describe "reporters" do
      before(:each) do
        @user = login("reporter")
        @file = test_file_path("invalid.txt")
      end

      it "can upload and then delete" do
        expect(Upload.count).to eq(0)
        visit "/admin/uploads/new"
        expect(page).to have_title("File Upload")
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        expect(page).to have_selector("span.alert", text: /cannot extract/i)
        expect(Upload.count).to eq(1)
        upload = Upload.first
        expect(upload.error).to_not be_blank
        expect(upload.tournament).to be_blank
        visit "/admin/uploads/#{upload.id}"
        expect(page).to have_title("Upload")
        page.click_link("Delete")
        expect(page).to have_title("File Upload")
        expect(Upload.count).to eq(0)
      end

      it "cannot delete uploads they don't own" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        expect(Upload.count).to eq(1)
        upload = Upload.first
        expect(upload.user).to eq(@user)
        @user = login("reporter")
        expect(upload.user).to_not eq(@user)
        visit "/admin/uploads/#{upload.id}"
        expect(page).to_not have_link("Delete")
      end
    end

    describe "officers" do
      before(:each) do
        @user = login("officer")
        @file = test_file_path("invalid.txt")
      end

      it "can delete uploads they don't own", js: true do
        expect(Upload.count).to eq(0)
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        expect(Upload.count).to eq(1)
        upload = Upload.first
        expect(upload.user).to eq(@user)
        @user = login("officer")
        expect(upload.user).to_not eq(@user)
        visit "/admin/uploads/#{upload.id}"
        page.click_link("Delete")
        # page.driver.browser.switch_to.alert.accept # don't use a confirmation here any more
        expect(page.current_path).to eq("/admin/uploads/new")
        expect(Upload.count).to eq(0)
      end
    end
  end

  describe "valid files" do
    describe "junior championships" do
      before(:each) do
        @user   = login("reporter")
        @ryan   = FactoryGirl.create(:icu_player, id: 6897,  last_name: "Griffiths", first_name: "Ryan-Rhys", dob: "1993-12-20")
        @jamie  = FactoryGirl.create(:icu_player, id: 5226,  last_name: "Flynn",     first_name: "Jamie")
        @leon   = FactoryGirl.create(:icu_player, id: 6409,  last_name: "Hulleman",  first_name: "Leon")
        @thomas = FactoryGirl.create(:icu_player, id: 10914, last_name: "Dunne",     first_name: "Thomas", dob: "1992-01-16")
      end

      it "should process Swiss Perfect" do
        visit "/admin/uploads/new"
        page.select "Swiss Perfect", from: "upload_format"
        page.fill_in "start", with: "2010-04-11"
        page.attach_file "file", test_file_path("junior_championships_u19_2010.zip")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "U-19 All Ireland")

        expect(Upload.count).to eq(1)
        expect(Tournament.count).to eq(1)
        expect(Player.where(status: "ok").count).to eq(4)
        expect(@thomas.players.size).to eq(1)
        expect(@ryan.players.size).to eq(1)
        expect(@jamie.players.size).to eq(1)
        expect(@leon.players.size).to eq(1)
        tournament = Tournament.last
        expect(tournament.name).to eq("U-19 All Ireland")
        expect(tournament.start.to_s).to eq("2010-04-11")
        expect(tournament.finish.to_s).to eq("2010-04-11")
        expect(tournament.players.map(&:name).join('|')).to eq("Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon")
        thomas, jamie, ryan, leon = tournament.players
        expect(ryan.results.size).to eq(3)
        expect(thomas.results.map(&:round).join("|")).to eq("1|2|3")
        expect(jamie.results.map(&:result).join("|")).to eq("W|L|W")
        expect(jamie.icu_id).to eq(5226)
        expect(jamie.icu_id).to eq(5226)
        expect(jamie.icu_rating).to eq(1633)
        expect(leon.results.map(&:colour).join("|")).to eq("B|B|W")
        expect(ryan.original_data).to eq("Griffiths, Ryan-Rhys, 6897, 1993-12-20, 2225")
        expect(thomas.original_data).to eq("Dunne, Thomas, 10914, 1992-01-16")
        expect(jamie.original_data).to eq("Flynn, Jamie, 5226, 1633")
        expect(leon.original_data).to eq("Hulleman, Leon, 6409, 1466")
      end

      it "should process Swiss Perfect Export" do
        visit "/admin/uploads/new"
        page.select "Swiss Perfect Export", from: "upload_format"
        page.fill_in "Tournament start date", with: "2010-04-11"
        page.fill_in "Tournament name", with: "U-19 All Ireland"
        page.attach_file "File to upload", test_file_path("junior_championships_u19_2010.txt")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "U-19 All Ireland")

        expect(Upload.count).to eq(1)
        expect(Tournament.count).to eq(1)
        expect(Player.where(status: "ok").count).to eq(4)
        expect(@thomas.players.size).to eq(1)
        expect(@ryan.players.size).to eq(1)
        expect(@jamie.players.size).to eq(1)
        expect(@leon.players.size).to eq(1)
        tournament = Tournament.last
        expect(tournament.name).to eq("U-19 All Ireland")
        expect(tournament.start.to_s).to eq("2010-04-11")
        expect(tournament.finish.to_s).to eq("2010-04-11")
        expect(tournament.players.map(&:name).join('|')).to eq("Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon")
        thomas, jamie, ryan, leon = tournament.players
        expect(ryan.results.map(&:result).join("|")).to eq("W|W|W")
        expect(thomas.results.map(&:colour).join("|")).to eq("||")
        expect(thomas.dob).to be_nil
        expect(jamie.results.size).to eq(3)
        expect(jamie.original_name).to eq("flynn, jamie")
        expect(jamie.icu_id).to eq(5226)
        expect(jamie.original_icu_id).to eq(5226)
        expect(jamie.fide_id).to be_nil
        expect(jamie.original_fide_id).to be_nil
        expect(leon.results.map(&:round).join("|")).to eq("1|2|3")
        expect(ryan.original_data).to eq("Griffiths, Ryan-Rhys, 6897")
        expect(thomas.original_data).to eq("Dunne, Thomas, 10914")
        expect(jamie.original_data).to eq("flynn, jamie, 5226")
        expect(leon.original_data).to eq("Hulleman, Leon, 6409")
      end

      it "should process Krause" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", test_file_path("junior_championships_u19_2010.tab")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "U-19 All Ireland")

        expect(Upload.count).to eq(1)
        expect(Tournament.count).to eq(1)
        expect(Player.where(status: "ok").count).to eq(4)
        expect(@thomas.players.size).to eq(1)
        expect(@ryan.players.size).to eq(1)
        expect(@jamie.players.size).to eq(1)
        expect(@leon.players.size).to eq(1)
        tournament = Tournament.last
        expect(tournament.name).to eq("U-19 All Ireland")
        expect(tournament.start.to_s).to eq("2010-04-11")
        expect(tournament.finish.to_s).to eq("2010-04-13")
        expect(tournament.players.map(&:name).join('|')).to eq("Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon")
        thomas, jamie, ryan, leon = tournament.players
        expect(ryan.results.map(&:colour).join("|")).to eq("W|W|B")
        expect(ryan.icu_id).to eq(6897)
        expect(ryan.icu_rating).to eq(2225)
        expect(thomas.results.size).to eq(3)
        expect(thomas.dob.to_s).to eq("1992-01-16")
        expect(thomas.icu_id).to eq(10914)
        expect(thomas.fide_id).to be_nil
        expect(jamie.results.map(&:round).join("|")).to eq("1|2|3")
        expect(leon.results.map(&:result).join("|")).to eq("L|W|L")
        expect(ryan.original_data).to eq("Griffiths, Ryan-Rhys, 6897, 1993-12-20, 2225")
        expect(thomas.original_data).to eq("dunne, thomas, 10914, 1992-01-16")
        expect(jamie.original_data).to eq("Flynn, Jamie, 5226, 1633")
        expect(leon.original_data).to eq("Hülleman, Leon, 6409, 1466")
        expect(leon.name).to eq("Hulleman, Leon")
      end
    end

    describe "isle of man" do
      before(:each) do
        @user   = login("reporter")
        @peter  = FactoryGirl.create(:icu_player, id: 159,   last_name: "Cafolla",   first_name: "Peter")
        @tony   = FactoryGirl.create(:icu_player, id: 456,   last_name: "Fox",       first_name: "Tony")
      end

      it "should process Foreign CSV" do
        visit "/admin/uploads/new"
        page.select "ICU-CSV", from: "upload_format"
        page.attach_file "file", test_file_path("isle_of_man_2007.csv")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "Isle of Man Masters, 2007")

        tournament = Tournament.last
        expect(tournament.name).to eq("Isle of Man Masters, 2007")
        expect(tournament.start.to_s).to eq("2007-09-22")
        expect(tournament.finish.to_s).to eq("2007-09-30")
        peter, tony = tournament.players.where(category: "icu_player").order(:last_name)
        doreen = peter.results.find_by_round(5).opponent
        expect(tony.name).to eq("Fox, Anthony")
        expect(tony.results.size).to eq(9)
        expect(tony.results.find_by_round(1).opponent.name).to eq("Taylor, Peter P.")
        expect(tony.results.find_by_round(1).opponent.original_name).to eq("Taylor, Peter P")
        expect(tony.results.find_by_round(4).colour).to eq('W')
        expect(tony.results.find_by_round(6).rateable).to be false
        expect(tony.results.find_by_round(9).result).to eq("D")
        expect(peter.results.size).to eq(9)
        expect(peter.results.where(rateable: true).size).to eq(9)  # should this be 8?
        expect(peter.score).to eq(3.0)
        expect(peter.results.map(&:opponent).map(&:fed).join("|")).to eq("ENG|NED|IRL|IRL|GER|ENG|ISR|AUS|SCO")
        expect(peter.results.map(&:opponent).map(&:fide_rating).join("|")).to eq("2198|2227|2100|2394|2151|2282|2205|2200|2223")
        expect(tony.results.find_by_round(7).opponent.title).to be_nil
        expect(doreen.name).to eq("Troyke, Doreen")
        expect(doreen.fide_rating).to eq(2151)
        expect(doreen.fed).to eq("GER")
        expect(doreen.title).to eq("WFM")
        expect(doreen.fide_rating).to eq(2151)
      end
    end

    describe "more Krause" do
      before(:each) do
        @user = login("reporter")
      end

      it "should handle Krause with invalid round dates" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", test_file_path("galway_major_2011.tab")
        page.click_button "Upload"

        expect(page).to have_selector("span.alert", text: /extract/i)
        expect(page).to have_selector(:xpath, "//tr/th[.='Errors']/following-sibling::td", text: /date/i)

        expect(Upload.count).to eq(1)
        expect(Tournament.count).to eq(0)

        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.select "Ignore all", from: "round_dates"
        page.attach_file "file", test_file_path("galway_major_2011.tab")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "Galway Major 2011")
        expect(page).to have_no_selector("span.alert")

        expect(Upload.count).to eq(2)
        expect(Tournament.count).to eq(1)
      end
    end

    describe "original data" do
      before(:each) do
        @user = login("reporter")
      end

      it "should be remembered" do
        visit "/admin/uploads/new"
        page.select "Swiss Perfect", from: "upload_format"
        page.fill_in "start", with: "2011-04-04"
        page.attach_file "file", test_file_path("rathmines_senior_2011.zip")
        page.click_button "Upload"

        expect(page).to have_selector("div span", text: "Rathmines Senior 2011")

        expect(Upload.count).to eq(1)
        expect(Tournament.count).to eq(1)
        tournament = Tournament.last
        expect(tournament.name).to eq("Rathmines Senior 2011")
        expect(tournament.original_name).to eq("Rathmines Senior 2011")
        expect(tournament.start.to_s).to eq("2011-04-04")
        expect(tournament.original_start.to_s).to eq("2011-04-04")
        expect(tournament.finish.to_s).to eq("2011-04-06")
        expect(tournament.original_finish).to be_nil
        expect(tournament.tie_breaks).to eq("progressive,buchholz,harkness")
        expect(tournament.original_tie_breaks).to eq("progressive,buchholz,harkness")
        expect(tournament.original_data).to eq("Rathmines Senior 2011, 2011-04-04, progressive|buchholz|harkness")
      end
    end

    describe "finish date" do
      describe "Swiss Perfect" do
        before(:each) do
          @user = login("reporter")
          visit "/admin/uploads/new"
          page.select "Swiss Perfect", from: "upload_format"
          page.attach_file "file", test_file_path("rathmines_senior_2011.zip")
          page.fill_in "start", with: "2011-01-01"
        end

        it "should guess finish date" do
          page.click_button "Upload"
          tournament = Tournament.last
          expect(tournament.start.to_s).to eq("2011-01-01")
          expect(tournament.finish.to_s).to eq("2011-01-03")
          expect(tournament.original_finish).to be_nil
        end

        it "should set finish date" do
          page.fill_in "finish", with: "2011-01-30"
          page.click_button "Upload"
          tournament = Tournament.last
          expect(tournament.start.to_s).to eq("2011-01-01")
          expect(tournament.finish.to_s).to eq("2011-01-30")
          expect(tournament.original_finish.to_s).to eq("2011-01-30")
        end
      end

      describe "Foreign CSV" do
        before(:each) do
          @user = login("reporter")
          visit "/admin/uploads/new"
          page.select "ICU-CSV", from: "upload_format"
          page.attach_file "file", test_file_path("isle_of_man_2007.csv")
        end

        it "should get finish date straight from file (since icu_tournament v1.6.0)" do
          page.click_button "Upload"
          tournament = Tournament.last
          expect(tournament.start.to_s).to eq("2007-09-22")
          expect(tournament.finish.to_s).to eq("2007-09-30")
        end
      end
    end
  end
end
