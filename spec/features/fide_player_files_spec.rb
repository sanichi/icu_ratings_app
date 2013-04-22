require 'spec_helper'

describe "FidePlayerFile" do
  def load_file(file, update=false)
    visit "/admin/fide_player_files/new"
    page.attach_file "fide_player_file[file]", test_file_path(file)
    page.check "Update" if update
    page.click_button "Upload"
  end

  before(:each) do
    login("officer")
  end

  describe "reporting without updating" do
    context "an empty DB" do
      it "should have neither FIDE nor ICU matches" do
        load_file("fide_player_file.xml")
        FidePlayer.count.should == 0
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /players in file: 12\b/i)
        page.should have_selector("ul li", text: /update option: off/i)
        page.should have_selector("ul li", text: /players in database: 0\b/i)
        page.should have_selector("ul li", text: /\b12 players split into 1 category\b/i)
        page.should have_selector("ul li", text: /\bno fide match and no icu suggested matches: 12\b/i)
        page.should have_selector("ul li", text: "Allen, Keith (M, 2501147) 1962-02-02")
        page.should have_selector("ul li", text: "Astaneh Lopez, Alex (M, 2501430) 1987-06-13")
        page.should have_selector("ul li", text: "Baburin, Alexander (M, 2500914) 1967-02-19")
        page.should have_selector("ul li", text: "Bradley, Sean (M, 2500132) 1954-01-11")
        page.should have_selector("ul li", text: "Brady, Stephen (M, 2500124) 1969-03-12")
        page.should have_selector("ul li", text: "Cronin, April (F, 2500370) 1960-02-20")
        page.should have_selector("ul li", text: "Orr, Mark J L (M, 2500035) 1955-11-09")
        page.should have_selector("ul li", text: "O'Cinneide, Mel (M, 2500620) 1965-01-06")
        page.should have_selector("ul li", text: "O'Muireagain, Colm (M, 2507382) 1966-09-25")
        page.should have_selector("ul li", text: "Quinn, Deborah (F, 2501333) 1969-11-20")
        page.should have_selector("ul li", text: "Quinn, Mark (M, 2500450) 1976-08-08")
        page.should have_selector("ul li", text: "Ui Laighleis, Gearoidin (F, 2501171) 1964-06-10")
      end
    end

    context "only FIDE matches" do
      it "should find them" do
        FactoryGirl.create(:fide_player, id: 2500035, last_name: "Orr", first_name: "Mark", fed: "IRL", born: 1955, title: "IM", gender: "M", icu_player: nil)
        FactoryGirl.create(:fide_player, id: 2500370, last_name: "Cronin", first_name: "April", fed: "IRL", born: 1960, gender: "F", icu_player: nil)
        FactoryGirl.create(:fide_player, id: 2507382, last_name: "O`Muireagain", first_name: "Colm", fed: "IRL", born: 1966, gender: "M", icu_player: nil)
        load_file("fide_player_file.xml")
        FidePlayer.count.should == 3
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /players in file: 12\b/i)
        page.should have_selector("ul li", text: /update option: off/i)
        page.should have_selector("ul li", text: /players in database: 3\b/i)
        page.should have_selector("ul li", text: /\b12 players split into 2 categories\b/i)
        page.should have_selector("ul li", text: /\bno fide match and no icu suggested matches: 9\b/i)
        page.should have_selector("ul li", text: /\bfide match but no icu match: 3\b/i)
      end
    end

    context "only ICU matches" do
      it "should find them" do
        FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-11-09", gender: "M")
        FactoryGirl.create(:icu_player, id: 87, last_name: "Bradley", first_name: "John", fed: "IRL", dob: "1954-01-11", gender: "M")
        FactoryGirl.create(:icu_player, id: 12275, last_name: "O'Muireagain", first_name: "Colm", fed: "IRL", dob: "1966-09-25", gender: "M")
        FactoryGirl.create(:icu_player, id: 3364, last_name: "Ui Laighleis", first_name: "Gearoidin", fed: "IRL", dob: "1964-06-10", gender: "F")
        load_file("fide_player_file.xml")
        FidePlayer.count.should == 0
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /players in file: 12\b/i)
        page.should have_selector("ul li", text: /update option: off/i)
        page.should have_selector("ul li", text: /players in database: 0\b/i)
        page.should have_selector("ul li", text: /\b12 players split into 2 categories\b/i)
        page.should have_selector("ul li", text: /\bno fide match and no icu suggested matches: 8\b/i)
        page.should have_selector("ul li", text: /\bno fide match with icu suggested matches: 4\b/i)
      end
    end

    context "FIDE and ICU matches" do
      it "should find them" do
        # FIDE and matched ICU
        icu = FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-11-09", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500035, last_name: "Orr", first_name: "Mark", fed: "IRL", born: 1955, title: "IM", gender: "M", icu_player: icu)
        icu = FactoryGirl.create(:icu_player, id: 87, last_name: "Bradley", first_name: "John", fed: "IRL", dob: "1954-01-11", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500132, last_name: "Bradley", first_name: "Sean", fed: "IRL", born: 1954, gender: "M", icu_player: icu)
        # FIDE and unmatched ICU
        FactoryGirl.create(:icu_player, id: 1402, last_name: "Quinn", first_name: "Mark", fed: "IRL", dob: "1976-08-08", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500450, last_name: "Quinn", first_name: "Mark", fed: "IRL", born: 1976, gender: "M", icu_player: nil)        
        # FIDE only
        FactoryGirl.create(:fide_player, id: 2501333, last_name: "Quinn", first_name: "Deborah", fed: "IRL", born: 1969, gender: "F", icu_player: nil)
        # ICU only
        FactoryGirl.create(:icu_player, id: 7085, last_name: "Baburin", first_name: "Alexander", fed: "IRL", dob: "1967-02-19", gender: "M")
        FactoryGirl.create(:icu_player, id: 90, last_name: "Brady", first_name: "Stephen", fed: "IRL", dob: "1969-03-12", gender: "M")
        FactoryGirl.create(:icu_player, id: 3364, last_name: "Ui Laighleis", first_name: "Gearoidin", fed: "IRL", dob: "1964-06-10", gender: "F")
        load_file("fide_player_file.xml")
        FidePlayer.count.should == 4
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /players in file: 12\b/i)
        page.should have_selector("ul li", text: /update option: off/i)
        page.should have_selector("ul li", text: /players in database: 4\b/i)
        page.should have_selector("ul li", text: /\b12 players split into 5 categories\b/i)
        page.should have_selector("ul li", text: /\bno fide match and no icu suggested matches: 5\b/i)
        page.should have_selector("ul li", text: /\bno fide match with icu suggested matches: 3\b/i)
        page.should have_selector("ul li", text: /\bfide match with icu suggested matches: 1\b/i)
        page.should have_selector("ul li", text: /\bfide match but no icu match: 1\b/i)
        page.should have_selector("ul li", text: /\bfide and icu match: 2\b/i)
      end
    end

    context "duplicates" do
      it "should be detected" do
        load_file("fide_player_file_duplicates.xml")
        FidePlayer.count.should == 0
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 14
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /players in file: 14\b/i)
        page.should have_selector("ul li", text: /update option: off/i)
        page.should have_selector("ul li", text: /players in database: 0\b/i)
        page.should have_selector("ul li", text: /duplicate ids: 2500035, 2500370\b/i)
        page.should have_selector("ul li", text: /\b14 players split into 2 categories\b/i)
        page.should have_selector("ul li", text: /\bno fide match and no icu suggested matches: 10\b/i)
        page.should have_selector("ul li", text: /\bduplicates: 4\b/i)
        page.should have_selector("ul li", text: "Allen, Keith (M, 2501147) 1962-02-02")
        page.should have_selector("ul li", text: "Astaneh Lopez, Alex (M, 2501430) 1987-06-13")
        page.should have_selector("ul li", text: "Baburin, Alexander (M, 2500914) 1967-02-19")
        page.should have_selector("ul li", text: "Bradley, Sean (M, 2500132) 1954-01-11")
        page.should have_selector("ul li", text: "Brady, Stephen (M, 2500124) 1969-03-12")
        page.should have_selector("ul li", text: "Cronin, April (F, 2500370, DUPLICATE) 1960-02-20")
        page.should have_selector("ul li", text: "Cronin, April (F, 2500370, DUPLICATE) 1960-02-20")
        page.should have_selector("ul li", text: "Orr, Mark J L (M, 2500035, DUPLICATE) 1955-11-09")
        page.should have_selector("ul li", text: "Orr, Mark (M, 2500035, DUPLICATE) 1955-11-09")
        page.should have_selector("ul li", text: "O'Cinneide, Mel (M, 2500620) 1965-01-06")
        page.should have_selector("ul li", text: "O'Muireagain, Colm (M, 2507382) 1966-09-25")
        page.should have_selector("ul li", text: "Quinn, Deborah (F, 2501333) 1969-11-20")
        page.should have_selector("ul li", text: "Quinn, Mark (M, 2500450) 1976-08-08")
        page.should have_selector("ul li", text: "Ui Laighleis, Gearoidin (F, 2501171) 1964-06-10")
      end
    end
  end

  describe "reporting and updating" do
    context "an empty DB" do
      it "should not create any new records" do
        load_file("fide_player_file.xml", true)
        FidePlayer.count.should == 0
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /update option: on/i)
        page.should have_selector("ul li", text: /new fide records created: 0\b/i)
        page.should have_selector("ul li", text: /new icu mappings created: 0\b/i)
        page.should have_selector("ul li", text: "Allen, Keith (M, 2501147) 1962-02-02")
        page.should have_selector("ul li", text: "Astaneh Lopez, Alex (M, 2501430) 1987-06-13")
        page.should have_selector("ul li", text: "Baburin, Alexander (M, 2500914) 1967-02-19")
        page.should have_selector("ul li", text: "Bradley, Sean (M, 2500132) 1954-01-11")
        page.should have_selector("ul li", text: "Brady, Stephen (M, 2500124) 1969-03-12")
        page.should have_selector("ul li", text: "Cronin, April (F, 2500370) 1960-02-20")
        page.should have_selector("ul li", text: "Orr, Mark J L (M, 2500035) 1955-11-09")
        page.should have_selector("ul li", text: "O'Cinneide, Mel (M, 2500620) 1965-01-06")
        page.should have_selector("ul li", text: "O'Muireagain, Colm (M, 2507382) 1966-09-25")
        page.should have_selector("ul li", text: "Quinn, Deborah (F, 2501333) 1969-11-20")
        page.should have_selector("ul li", text: "Quinn, Mark (M, 2500450) 1976-08-08")
        page.should have_selector("ul li", text: "Ui Laighleis, Gearoidin (F, 2501171) 1964-06-10")
      end
    end

    context "only FIDE matches" do
      it "should not create any new records" do
        FactoryGirl.create(:fide_player, id: 2500035, last_name: "Orr", first_name: "Mark", fed: "IRL", born: 1955, title: "IM", gender: "M", icu_player: nil)
        FactoryGirl.create(:fide_player, id: 2500370, last_name: "Cronin", first_name: "April", fed: "IRL", born: 1960, gender: "F", icu_player: nil)
        FactoryGirl.create(:fide_player, id: 2507382, last_name: "O`Muireagain", first_name: "Colm", fed: "IRL", born: 1966, gender: "M", icu_player: nil)
        load_file("fide_player_file.xml", true)
        FidePlayer.count.should == 3
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /update option: on/i)
        page.should have_selector("ul li", text: /new fide records created: 0\b/i)
        page.should have_selector("ul li", text: /new icu mappings created: 0\b/i)
      end
    end

    context "only ICU matches" do
      it "should create new records and mappings" do
        FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-11-09", gender: "M")
        FactoryGirl.create(:icu_player, id: 87, last_name: "Bradley", first_name: "John", fed: "IRL", dob: "1954-01-11", gender: "M")
        FactoryGirl.create(:icu_player, id: 12275, last_name: "O'Muireagain", first_name: "Colm", fed: "IRL", dob: "1966-09-25", gender: "M")
        FactoryGirl.create(:icu_player, id: 3364, last_name: "Ui Laighleis", first_name: "Gearoidin", fed: "IRL", dob: "1964-06-10", gender: "F")
        load_file("fide_player_file.xml", true)
        FidePlayer.count.should == 4
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 4
        fpf.new_icu_mappings.should == 4
        page.should have_selector("ul li", text: /update option: on/i)
        page.should have_selector("ul li", text: /new fide records created: 4\b/i)
        page.should have_selector("ul li", text: /new icu mappings created: 4\b/i)
        page.should have_selector("ul li", text: "Bradley, Sean (M, 2500132) 1954-01-11 (created new FIDE record, created new ICU mapping)")
        page.should have_selector("ul li", text: "Orr, Mark J L (M, 2500035) 1955-11-09 (created new FIDE record, created new ICU mapping)")
        page.should have_selector("ul li", text: "O'Muireagain, Colm (M, 2507382) 1966-09-25 (created new FIDE record, created new ICU mapping)")
        page.should have_selector("ul li", text: "Ui Laighleis, Gearoidin (F, 2501171) 1964-06-10 (created new FIDE record, created new ICU mapping)")
      end
    end

    context "FIDE and ICU matches" do
      it "should create new records and mappings" do
        # FIDE and matched ICU
        icu = FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-11-09", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500035, last_name: "Orr", first_name: "Mark", fed: "IRL", born: 1955, title: "IM", gender: "M", icu_player: icu)
        icu = FactoryGirl.create(:icu_player, id: 87, last_name: "Bradley", first_name: "John", fed: "IRL", dob: "1954-01-11", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500132, last_name: "Bradley", first_name: "Sean", fed: "IRL", born: 1954, gender: "M", icu_player: icu)
        # FIDE and unmatched ICU
        FactoryGirl.create(:icu_player, id: 1402, last_name: "Quinn", first_name: "Mark", fed: "IRL", dob: "1976-08-08", gender: "M")
        FactoryGirl.create(:fide_player, id: 2500450, last_name: "Quinn", first_name: "Mark", fed: "IRL", born: 1976, gender: "M", icu_player: nil)        
        # FIDE only
        FactoryGirl.create(:fide_player, id: 2501333, last_name: "Quinn", first_name: "Deborah", fed: "IRL", born: 1969, gender: "F", icu_player: nil)
        # ICU only
        FactoryGirl.create(:icu_player, id: 7085, last_name: "Baburin", first_name: "Alexander", fed: "IRL", dob: "1967-02-19", gender: "M")
        FactoryGirl.create(:icu_player, id: 90, last_name: "Brady", first_name: "Stephen", fed: "IRL", dob: "1969-03-12", gender: "M")
        FactoryGirl.create(:icu_player, id: 3364, last_name: "Ui Laighleis", first_name: "Gearoidin", fed: "IRL", dob: "1964-06-10", gender: "F")
        load_file("fide_player_file.xml", true)
        FidePlayer.count.should == 7
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 12
        fpf.new_fide_records.should == 3
        fpf.new_icu_mappings.should == 4
        page.should have_selector("ul li", text: /update option: on/i)
        page.should have_selector("ul li", text: /new fide records created: 3\b/i)
        page.should have_selector("ul li", text: /new icu mappings created: 4\b/i)
        page.should have_selector("ul li", text: "Allen, Keith (M, 2501147) 1962-02-02")
        page.should have_selector("ul li", text: "Astaneh Lopez, Alex (M, 2501430) 1987-06-13")
        page.should have_selector("ul li", text: "Baburin, Alexander (M, 2500914) 1967-02-19 (created new FIDE record, created new ICU mapping)")
        page.should have_selector("ul li", text: "Bradley, Sean (M, 2500132, 87) 1954-01-11")
        page.should have_selector("ul li", text: "Brady, Stephen (M, 2500124) 1969-03-12 (created new FIDE record, created new ICU mapping)")
        page.should have_selector("ul li", text: "Cronin, April (F, 2500370) 1960-02-20")
        page.should have_selector("ul li", text: "Orr, Mark J L (M, 2500035, 1350) 1955-11-09")
        page.should have_selector("ul li", text: "O'Cinneide, Mel (M, 2500620) 1965-01-06")
        page.should have_selector("ul li", text: "O'Muireagain, Colm (M, 2507382) 1966-09-25")
        page.should have_selector("ul li", text: "Quinn, Deborah (F, 2501333) 1969-11-20")
        page.should have_selector("ul li", text: "Quinn, Mark (M, 2500450) 1976-08-08 (created new ICU mapping)")
        page.should have_selector("ul li", text: "Ui Laighleis, Gearoidin (F, 2501171) 1964-06-10 (created new FIDE record, created new ICU mapping)")
      end
    end

    context "duplicates" do
      it "should not create new records based on duplicates" do
        FactoryGirl.create(:icu_player, id: 1350, last_name: "Orr", first_name: "Mark", fed: "IRL", dob: "1955-11-09", gender: "M")
        FactoryGirl.create(:icu_player, id: 271, last_name: "Cronin", first_name: "April", fed: "IRL", dob: "1960-02-20", gender: "F")
        load_file("fide_player_file_duplicates.xml", true)
        FidePlayer.count.should == 0
        (fpf = FidePlayerFile.first).should_not be_nil
        fpf.players_in_file.should == 14
        fpf.new_fide_records.should == 0
        fpf.new_icu_mappings.should == 0
        page.should have_selector("ul li", text: /update option: on/i)
        page.should have_selector("ul li", text: /new fide records created: 0\b/i)
        page.should have_selector("ul li", text: /new icu mappings created: 0\b/i)
      end
    end
  end

  describe "errors" do
    context "no player records" do
      it "should cause immediate error" do
        load_file("fide_player_file_empty.xml", true)
        FidePlayerFile.count.should == 0
        page.should have_selector("div.flash span.alert", text: "Uploaded XML contains no Irish players")
      end
    end

    context "invalid XML" do
      it "should cause immediate error" do
        load_file("fide_player_file_invalid.xml", true)
        FidePlayerFile.count.should == 0
        page.should have_selector("div.flash span.alert", text: "Uploaded XML contains no Irish players")
      end
    end
  end
end
