# encoding: UTF-8
require 'spec_helper'

describe Admin::UploadsController do
  def sample_players
    IcuPlayer.all.each { |p| p.delete }
    @ryan   = Factory(:icu_player, id: 6897,  last_name: "Griffiths", first_name: "Ryan-Rhys", dob: "1993-12-20")
    @jamie  = Factory(:icu_player, id: 5226,  last_name: "Flynn",     first_name: "Jamie")
    @leon   = Factory(:icu_player, id: 6409,  last_name: "Hulleman",  first_name: "Leon")
    @thomas = Factory(:icu_player, id: 10914, last_name: "Dunne",     first_name: "Thomas", dob: "1992-01-16")
    @peter  = Factory(:icu_player, id: 159,   last_name: "Cafolla",   first_name: "Peter")
    @tony   = Factory(:icu_player, id: 456,   last_name: "Fox",       first_name: "Tony")
  end

  describe "test_upload utility" do
    it "should create uploaded files for testing" do
      upload = test_upload("junior_championships_u19_2010.zip")
      upload.original_filename.should == "junior_championships_u19_2010.zip"
      upload.content_type.should == "application/octet-stream"
    end
  end

  describe "POST 'create'" do
    before(:each) do
      session[:user_id] = Factory(:user, role: "reporter").id
    end

    describe "valid SwissPerfect file" do
      before(:each) do
        @params =
        {
          file:   test_upload("junior_championships_u19_2010.zip"),
          upload: { format: "SwissPerfect" },
          start:  "2010-04-11",
          feds:   "",
        }
        sample_players
      end

      it "should be processed correctly" do
        post "create", @params
        response.should redirect_to(admin_tournament_path(Tournament.last.id))

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 4
        @thomas.players.size.should == 1
        @ryan.players.size.should == 1
        @jamie.players.size.should == 1
        @leon.players.size.should == 1
        tournament = Tournament.last
        tournament.name.should == "U - 19 All Ireland"
        tournament.start.to_s.should == "2010-04-11"
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
    end

    describe "valid Krause file" do
      before(:each) do
        @params =
        {
          file:   test_upload("junior_championships_u19_2010.tab"),
          upload: { format: "Krause" },
          feds:   "",
        }
        sample_players
      end

      it "should be processed correctly" do
        post "create", @params
        response.should redirect_to(admin_tournament_path(Tournament.last.id))

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

    describe "Krause file with invalid round dates" do
      before(:each) do
        @params =
        {
          file:   test_upload("galway_major_2011.tab"),
          upload: { format: "Krause" },
          feds:   "",
        }
      end

      it "should fail" do
        post "create", @params
        Tournament.count.should == 0
        Upload.count.should == 1
        upload = Upload.last
        response.should redirect_to(admin_upload_path(upload.id))
        upload.error.should match(/date.*not match/)
      end

      it "should suceed if round dates are ignored" do
        @params[:round_dates] = "ignore"
        post "create", @params
        Tournament.count.should == 1
        Upload.count.should == 1
        tournament = Tournament.last
        response.should redirect_to(admin_tournament_path(tournament.id))
        tournament.name.should == "Galway Major 2011"
      end
    end

    describe "valid SwissPerfect export file" do
      before(:each) do
        @params =
        {
          file:   test_upload("junior_championships_u19_2010.txt"),
          upload: { format: "SPExport" },
          name:   "U19 All Ireland",
          start:  "2010-04-11",
        }
        sample_players
      end

      it "should be processed correctly" do
        post "create", @params
        response.should redirect_to(admin_tournament_path(Tournament.last.id))

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 4
        @thomas.players.size.should == 1
        @ryan.players.size.should == 1
        @jamie.players.size.should == 1
        @leon.players.size.should == 1

        tournament = Tournament.last
        tournament.name.should == "U19 All Ireland"
        tournament.start.to_s.should == "2010-04-11"
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
    end

    describe "valid ForeignCSV file" do
      before(:each) do
        @params =
        {
          file:   test_upload("isle_of_man_2007.csv"),
          upload: { format: "ForeignCSV" },
        }
        sample_players
      end

      it "should be processed correctly" do
        post 'create', @params
        response.should redirect_to(admin_tournament_path(Tournament.last.id))

        Upload.count.should == 1
        Tournament.count.should == 1
        Player.where(status: "ok").count.should == 15
        Player.where(category: "icu_player").count.should == 2
        Player.where(category: "foreign_player").count.should == 12
        @peter.players.size.should == 1
        @tony.players.size.should == 1

        tournament = Tournament.last
        tournament.name.should == "Isle of Man Masters, 2007"
        tournament.start.to_s.should == "2007-09-22"
        peter, tony = tournament.players.where(category: "icu_player").order(:last_name)
        doreen = peter.results.find_by_round(5).opponent
        tony.name.should == "Fox, Anthony"
        tony.results.size.should == 9
        tony.results.find_by_round(1).opponent.name.should == "Taylor, Peter P."
        tony.results.find_by_round(1).opponent.original_name.should == "Taylor, Peter P"
        tony.results.find_by_round(4).colour.should == 'W'
        tony.results.find_by_round(6).rateable.should be_false
        tony.results.find_by_round(9).result.should == "D"
        peter.results.size.should == 9
        peter.results.where(rateable: true).size.should == 9  # should this be 8?
        peter.score.should == 3.0
        peter.results.map(&:opponent).map(&:fed).join("|").should == "ENG|NED|IRL|IRL|GER|ENG|ISR|AUS|SCO"
        peter.results.map(&:opponent).map(&:fide_rating).join("|").should == "2198||2100|2394|2151|2282|2205|2200|2223"
        tony.results.find_by_round(7).opponent.title.should be_nil
        doreen.name.should == "Troyke, Doreen"
        doreen.fide_rating.should == 2151
        doreen.fed.should == "GER"
        doreen.title.should == "WFM"
        doreen.fide_rating.should == 2151
      end
    end

    describe "original data" do
      before(:each) do
        @params =
        {
          file:   test_upload("rathmines_senior_2011.zip"),
          upload: { format: "SwissPerfect" },
          start:  "2011-04-04",
          feds:   "",
        }
      end

      it "should be remembered" do
        post "create", @params
        response.should redirect_to(admin_tournament_path(Tournament.last.id))

        Upload.count.should == 1
        Tournament.count.should == 1
        tournament = Tournament.last
        tournament.name.should == "Rathmines Senior 2011"
        tournament.original_name.should == "Rathmines Senior 2011"
        tournament.start.to_s.should == "2011-04-04"
        tournament.original_start.to_s.should == "2011-04-04"
        tournament.finish.should be_nil
        tournament.original_finish.should be_nil
        tournament.tie_breaks.should == "progressive,buchholz,harkness"
        tournament.original_tie_breaks.should == "progressive,buchholz,harkness"
        tournament.original_data.should == "Rathmines Senior 2011, 2011-04-04, progressive|buchholz|harkness"
      end
    end
  end
end