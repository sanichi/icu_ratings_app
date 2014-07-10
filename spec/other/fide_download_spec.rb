# encoding: UTF-8
require 'spec_helper'

module FIDE
  describe Download do
    before(:each) do
      @players_list = File.open("#{Rails.root}/spec/files/players_list.xml", "r:US-ASCII:UTF-8") { |f| f.read }
    end

    it "sanity check" do
      @players_list.length.should be > 0
      @players_list.encoding.name.should == "UTF-8"
      @players_list.valid_encoding?.should be true
    end

    it "should retrieve Irish players" do
      hash = Hash.new
      sax = FIDE::Download::Parser.new do |p|
        if p["country"] == "IRL"
          player = FIDE::Download::Player.new(p)
          hash[player.id] = player
        end
      end
      parser = Nokogiri::XML::SAX::Parser.new(sax)
      parser.parse(@players_list)
      hash.size.should == 6

      me = hash[2500035]
      me.last_name.should == "Orr"
      me.first_name.should == "Mark J L"
      me.gender.should == "M"
      me.born.should == 1955
      me.rating.should == 2240
      me.games.should == 0
      me.title.should == "IM"
      me.fed.should == "IRL"
      me.active.should be true

      april = hash[2500370]
      april.last_name.should == "Cronin"
      april.first_name.should == "April"
      april.gender.should == "F"
      april.born.should == 1960
      april.rating.should == 2055
      april.games.should == 0
      april.title.should be_nil
      april.fed.should == "IRL"
      april.active.should be false

      gearoidin = hash[2501171]
      gearoidin.last_name.should == "Ui Laighleis"
      gearoidin.first_name.should == "Gearoidin"
      gearoidin.gender.should == "F"
      gearoidin.born.should == 1964
      gearoidin.rating.should == 1894
      gearoidin.games.should == 0
      gearoidin.title.should == "WCM"
      gearoidin.fed.should == "IRL"
      gearoidin.active.should be true

      mark = hash[2500450]
      mark.last_name.should == "Quinn"
      mark.first_name.should == "Mark"
      mark.gender.should == "M"
      mark.born.should == 1976
      mark.rating.should == 2388
      mark.games.should == 0
      mark.title.should == "IM"
      mark.fed.should == "IRL"
      mark.active.should be true

      bernard = hash[2500019]
      bernard.last_name.should == "Kernan"
      bernard.first_name.should == "Bernard"
      bernard.gender.should == "M"
      bernard.born.should == 1955
      bernard.rating.should == 2380
      bernard.games.should == 0
      bernard.title.should be_nil
      bernard.fed.should == "IRL"
      bernard.active.should be false

      debbie = hash[4413504]
      debbie.last_name.should == "Quinn"
      debbie.first_name.should == "Deborah"
      debbie.gender.should == "F"
      debbie.born.should == 1969
      debbie.rating.should == 1841
      debbie.games.should == 0
      debbie.title.should be_nil
      debbie.fed.should == "IRL"
      debbie.active.should be false
    end

    it "should retrieve foreign players" do
      hash = Hash.new
      sax = FIDE::Download::Parser.new do |p|
        unless p["country"] == "IRL" || p["flag"].to_s.match(/i/)
          player = FIDE::Download::Player.new(p)
          hash[player.id] = player
        end
      end
      parser = Nokogiri::XML::SAX::Parser.new(sax)
      parser.parse(@players_list)
      hash.size.should == 3

      magnus = hash[1503014]
      magnus.last_name.should == "Carlsen"
      magnus.first_name.should == "Magnus"
      magnus.gender.should == "M"
      magnus.born.should == 1990
      magnus.rating.should == 2843
      magnus.games.should == 10
      magnus.title.should == "GM"
      magnus.fed.should == "NOR"
      magnus.active.should be true

      shakri = hash[13401319]
      shakri.last_name.should == "Mamedyarov"
      shakri.first_name.should == "Shakhriyar"
      shakri.gender.should == "M"
      shakri.born.should == 1985
      shakri.rating.should == 2729
      shakri.games.should == 0
      shakri.title.should == "GM"
      shakri.fed.should == "AZE"
      shakri.active.should be true

      sofia = hash[24150797]
      sofia.last_name.should == "Zyzlova"
      sofia.first_name.should == "Sofia"
      sofia.gender.should == "F"
      sofia.born.should be nil
      sofia.rating.should == 2080
      sofia.games.should == 0
      sofia.title.should be_nil
      sofia.fed.should == "RUS"
      sofia.active.should be true
    end
  end
end
