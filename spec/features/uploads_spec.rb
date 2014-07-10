# encoding: UTF-8
require 'spec_helper'

describe "Upload" do
  describe "guests" do
    it "cannot upload files" do
      visit "/admin/uploads/new"
      page.should have_selector("span.alert", text: /not authorized/i)
    end
  end

  describe "members" do
    it "cannot upload files" do
      login("member")
      visit "/admin/uploads/new"
      page.should have_selector("span.alert", text: /not authorized/i)
    end
  end

  describe "invalid files" do
    describe "reporters" do
      before(:each) do
        @user = login("reporter")
        @file = test_file_path("invalid.txt")
      end

      it "can upload and then delete" do
        Upload.count.should == 0
        visit "/admin/uploads/new"
        page.should have_title("File Upload")
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        page.should have_selector("span.alert", text: /cannot extract/i)
        Upload.count.should == 1
        upload = Upload.first
        upload.error.should_not be_blank
        upload.tournament.should be_blank
        visit "/admin/uploads/#{upload.id}"
        page.should have_title("Upload")
        page.click_link("Delete")
        page.should have_title("File Upload")
        Upload.count.should == 0
      end

      it "cannot delete uploads they don't own" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        Upload.count.should == 1
        upload = Upload.first
        upload.user.should == @user
        @user = login("reporter")
        upload.user.should_not == @user
        visit "/admin/uploads/#{upload.id}"
        page.should_not have_link("Delete")
      end
    end

    describe "officers" do
      before(:each) do
        @user = login("officer")
        @file = test_file_path("invalid.txt")
      end

      it "can delete uploads they don't own", js: true do
        Upload.count.should == 0
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", @file
        page.click_button "Upload"
        Upload.count.should == 1
        upload = Upload.first
        upload.user.should == @user
        @user = login("officer")
        upload.user.should_not == @user
        visit "/admin/uploads/#{upload.id}"
        page.click_link("Delete")
        # page.driver.browser.switch_to.alert.accept # don't use a confirmation here any more
        page.current_path.should == "/admin/uploads/new"
        Upload.count.should == 0
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

        page.should have_selector("div span", text: "U-19 All Ireland")

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 4
        @thomas.players.size.should == 1
        @ryan.players.size.should == 1
        @jamie.players.size.should == 1
        @leon.players.size.should == 1
        tournament = Tournament.last
        tournament.name.should == "U-19 All Ireland"
        tournament.start.to_s.should == "2010-04-11"
        tournament.finish.to_s.should == "2010-04-11"
        tournament.players.map(&:name).join('|').should == "Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon"
        thomas, jamie, ryan, leon = tournament.players
        ryan.results.size.should == 3
        thomas.results.map(&:round).join("|").should == "1|2|3"
        jamie.results.map(&:result).join("|").should == "W|L|W"
        jamie.icu_id.should == 5226
        jamie.icu_id.should == 5226
        jamie.icu_rating.should == 1633
        leon.results.map(&:colour).join("|").should == "B|B|W"
        ryan.original_data.should == "Griffiths, Ryan-Rhys, 6897, 1993-12-20, 2225"
        thomas.original_data.should == "Dunne, Thomas, 10914, 1992-01-16"
        jamie.original_data.should == "Flynn, Jamie, 5226, 1633"
        leon.original_data.should == "Hulleman, Leon, 6409, 1466"
      end

      it "should process Swiss Perfect Export" do
        visit "/admin/uploads/new"
        page.select "Swiss Perfect Export", from: "upload_format"
        page.fill_in "Tournament start date", with: "2010-04-11"
        page.fill_in "Tournament name", with: "U-19 All Ireland"
        page.attach_file "File to upload", test_file_path("junior_championships_u19_2010.txt")
        page.click_button "Upload"

        page.should have_selector("div span", text: "U-19 All Ireland")

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 4
        @thomas.players.size.should == 1
        @ryan.players.size.should == 1
        @jamie.players.size.should == 1
        @leon.players.size.should == 1
        tournament = Tournament.last
        tournament.name.should == "U-19 All Ireland"
        tournament.start.to_s.should == "2010-04-11"
        tournament.finish.to_s.should == "2010-04-11"
        tournament.players.map(&:name).join('|').should == "Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon"
        thomas, jamie, ryan, leon = tournament.players
        ryan.results.map(&:result).join("|").should == "W|W|W"
        thomas.results.map(&:colour).join("|").should == "||"
        thomas.dob.should be_nil
        jamie.results.size.should == 3
        jamie.original_name.should == "flynn, jamie"
        jamie.icu_id.should == 5226
        jamie.original_icu_id.should == 5226
        jamie.fide_id.should be_nil
        jamie.original_fide_id.should be_nil
        leon.results.map(&:round).join("|").should == "1|2|3"
        ryan.original_data.should == "Griffiths, Ryan-Rhys, 6897"
        thomas.original_data.should == "Dunne, Thomas, 10914"
        jamie.original_data.should == "flynn, jamie, 5226"
        leon.original_data.should == "Hulleman, Leon, 6409"
      end

      it "should process Krause" do
        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.attach_file "file", test_file_path("junior_championships_u19_2010.tab")
        page.click_button "Upload"

        page.should have_selector("div span", text: "U-19 All Ireland")

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 4
        @thomas.players.size.should == 1
        @ryan.players.size.should == 1
        @jamie.players.size.should == 1
        @leon.players.size.should == 1
        tournament = Tournament.last
        tournament.name.should == "U-19 All Ireland"
        tournament.start.to_s.should == "2010-04-11"
        tournament.finish.to_s.should == "2010-04-13"
        tournament.players.map(&:name).join('|').should == "Dunne, Thomas|Flynn, Jamie|Griffiths, Ryan-Rhys|Hulleman, Leon"
        thomas, jamie, ryan, leon = tournament.players
        ryan.results.map(&:colour).join("|").should == "W|W|B"
        ryan.icu_id.should == 6897
        ryan.icu_rating.should == 2225
        thomas.results.size.should == 3
        thomas.dob.to_s.should == "1992-01-16"
        thomas.icu_id.should == 10914
        thomas.fide_id.should be_nil
        jamie.results.map(&:round).join("|").should == "1|2|3"
        leon.results.map(&:result).join("|").should == "L|W|L"
        ryan.original_data.should == "Griffiths, Ryan-Rhys, 6897, 1993-12-20, 2225"
        thomas.original_data.should == "dunne, thomas, 10914, 1992-01-16"
        jamie.original_data.should == "Flynn, Jamie, 5226, 1633"
        leon.original_data.should == "Hülleman, Leon, 6409, 1466"
        leon.name.should == "Hulleman, Leon"
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

        page.should have_selector("div span", text: "Isle of Man Masters, 2007")

        tournament = Tournament.last
        tournament.name.should == "Isle of Man Masters, 2007"
        tournament.start.to_s.should == "2007-09-22"
        tournament.finish.to_s.should == "2007-09-30"
        peter, tony = tournament.players.where(category: "icu_player").order(:last_name)
        doreen = peter.results.find_by_round(5).opponent
        tony.name.should == "Fox, Anthony"
        tony.results.size.should == 9
        tony.results.find_by_round(1).opponent.name.should == "Taylor, Peter P."
        tony.results.find_by_round(1).opponent.original_name.should == "Taylor, Peter P"
        tony.results.find_by_round(4).colour.should == 'W'
        tony.results.find_by_round(6).rateable.should be false
        tony.results.find_by_round(9).result.should == "D"
        peter.results.size.should == 9
        peter.results.where(rateable: true).size.should == 9  # should this be 8?
        peter.score.should == 3.0
        peter.results.map(&:opponent).map(&:fed).join("|").should == "ENG|NED|IRL|IRL|GER|ENG|ISR|AUS|SCO"
        peter.results.map(&:opponent).map(&:fide_rating).join("|").should == "2198|2227|2100|2394|2151|2282|2205|2200|2223"
        tony.results.find_by_round(7).opponent.title.should be_nil
        doreen.name.should == "Troyke, Doreen"
        doreen.fide_rating.should == 2151
        doreen.fed.should == "GER"
        doreen.title.should == "WFM"
        doreen.fide_rating.should == 2151
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

        page.should have_selector("span.alert", text: /extract/i)
        page.should have_selector(:xpath, "//tr/th[.='Errors']/following-sibling::td", text: /date/i)

        Upload.count.should == 1
        Tournament.count.should == 0

        visit "/admin/uploads/new"
        page.select "FIDE-Krause", from: "upload_format"
        page.select "Ignore all", from: "round_dates"
        page.attach_file "file", test_file_path("galway_major_2011.tab")
        page.click_button "Upload"

        page.should have_selector("div span", text: "Galway Major 2011")
        page.should have_no_selector("span.alert")

        Upload.count.should == 2
        Tournament.count.should == 1
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

        page.should have_selector("div span", text: "Rathmines Senior 2011")

        Upload.count.should == 1
        Tournament.count.should == 1
        tournament = Tournament.last
        tournament.name.should == "Rathmines Senior 2011"
        tournament.original_name.should == "Rathmines Senior 2011"
        tournament.start.to_s.should == "2011-04-04"
        tournament.original_start.to_s.should == "2011-04-04"
        tournament.finish.to_s.should == "2011-04-06"
        tournament.original_finish.should be_nil
        tournament.tie_breaks.should == "progressive,buchholz,harkness"
        tournament.original_tie_breaks.should == "progressive,buchholz,harkness"
        tournament.original_data.should == "Rathmines Senior 2011, 2011-04-04, progressive|buchholz|harkness"
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
          tournament.start.to_s.should == "2011-01-01"
          tournament.finish.to_s.should == "2011-01-03"
          tournament.original_finish.should be_nil
        end

        it "should set finish date" do
          page.fill_in "finish", with: "2011-01-30"
          page.click_button "Upload"
          tournament = Tournament.last
          tournament.start.to_s.should == "2011-01-01"
          tournament.finish.to_s.should == "2011-01-30"
          tournament.original_finish.to_s.should == "2011-01-30"
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
          tournament.start.to_s.should == "2007-09-22"
          tournament.finish.to_s.should == "2007-09-30"
        end
      end
    end
  end
end
