require 'spec_helper'

describe FidePlayer do
  context "validation" do
    before(:each) do
      @m = IcuPlayer.create(first_name: "M.", last_name: "Orr", deceased: false, joined: "1980-01-01")
    end

    it "ICU player IDs, if they exist, should be unique" do
      lambda { FidePlayer.create!(first_name: "P.", last_name: "Ure", fed: "POL", gender: "M") }.should_not raise_error
      lambda { FidePlayer.create!(first_name: "Q.", last_name: "Cho", fed: "CHN", gender: "F") }.should_not raise_error
      lambda { FidePlayer.create!(first_name: "J.", last_name: "Orr", fed: "IRL", gender: "M", icu_id: @m.id) }.should_not raise_error
      lambda { FidePlayer.create!(first_name: "G.", last_name: "Sax", fed: "HUN", gender: "M", icu_id: @m.id) }.should raise_error(ActiveRecord::RecordInvalid, /taken/)
    end
  end

  context "name" do
    before(:each) do
      @p = Factory(:fide_player, title: "IM")
      @r = Factory(:fide_player)
    end

    it "no options or single boolean option" do
      @p.name.should == "#{@p.last_name}, #{@p.first_name}"
      @p.name(true).should == "#{@p.last_name}, #{@p.first_name}"
      @p.name(false).should == "#{@p.first_name} #{@p.last_name}"
    end

    it "symbolic options" do
      @p.name(:title).should == "#{@p.first_name} #{@p.last_name}, IM"
      @p.name(:reversed, :title).should == "#{@p.last_name}, #{@p.first_name}, IM"
      @p.name(:title, :brackets).should == "#{@p.first_name} #{@p.last_name} (IM)"
      @p.name(:title, :brackets, :reversed).should == "#{@p.last_name}, #{@p.first_name} (IM)"
    end
  end
end
