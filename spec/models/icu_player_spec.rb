require 'spec_helper'

describe IcuPlayer do
  context "alternative names" do
    it "should generate SQL for names with no alternatives" do
      IcuPlayer.first_name_like("Liam", "Brady").should == "first_name LIKE '%Liam%'"
      IcuPlayer.last_name_like("Orr", "Mark").should == "last_name LIKE '%Orr%'"
    end

    it "should generate SQL for names with alternatives" do
      IcuPlayer.first_name_like("Debbie", "Quinn").should == "first_name LIKE '%Debbie%' OR first_name LIKE '%Deborah%'"
      IcuPlayer.first_name_like("Tony", "Fox").should == "first_name LIKE '%Anthony%' OR first_name LIKE '%Tony%'"
      IcuPlayer.last_name_like("Murphy", "Oissine").should == "last_name LIKE '%Murchadha%' OR last_name LIKE '%Murphy%'"
    end

    it "should generate SQL for names with conditional alternatives" do
      IcuPlayer.first_name_like("Sean", "Bradley").should == "first_name LIKE '%John%' OR first_name LIKE '%Sean%'"
      IcuPlayer.first_name_like("Sean", "Brady").should == "first_name LIKE '%Sean%'"
      IcuPlayer.last_name_like("Quinn", "Debbie").should == "last_name LIKE '%Benjamin%' OR last_name LIKE '%Quinn%'"
      IcuPlayer.last_name_like("Quinn", "Mark").should == "last_name LIKE '%Quinn%'"
    end

    it "should properly escape values to stop SQL injection" do
      IcuPlayer.last_name_like("\\''; DROP TABLE users; --", "Debbie").should match(/\\\\''''/)
      IcuPlayer.first_name_like("' or '1'='1", "Quinn").should match(/''/)
    end
  end

  context "name" do
    before(:each) do
      @p = FactoryGirl.create(:icu_player, title: "IM", club: "Bangor")
      @q = FactoryGirl.create(:icu_player, title: "GM")
      @r = FactoryGirl.create(:icu_player)
    end

    it "no options or single boolean option" do
      @p.name.should == "#{@p.last_name}, #{@p.first_name}"
      @p.name(true).should == "#{@p.last_name}, #{@p.first_name}"
      @p.name(false).should == "#{@p.first_name} #{@p.last_name}"
    end

    it "symbolic options" do
      @p.name(:title).should == "#{@p.first_name} #{@p.last_name}, IM"
      @p.name(:club).should == "#{@p.first_name} #{@p.last_name}, Bangor"
      @p.name(:reversed, :title).should == "#{@p.last_name}, #{@p.first_name}, IM"
      @p.name(:title, :brackets).should == "#{@p.first_name} #{@p.last_name} (IM)"
      @p.name(:club, :title, :brackets).should == "#{@p.first_name} #{@p.last_name} (Bangor, IM)"
      @p.name(:title, :club, :brackets).should == "#{@p.first_name} #{@p.last_name} (IM, Bangor)"
      @q.name(:title, :club, :brackets).should == "#{@q.first_name} #{@q.last_name} (GM)"
      @r.name(:title, :club, :brackets).should == "#{@r.first_name} #{@r.last_name}"
      @p.name(:title, :club).should == "#{@p.first_name} #{@p.last_name}, IM, Bangor"
      @q.name(:title, :club).should == "#{@q.first_name} #{@q.last_name}, GM"
      @r.name(:title, :club).should == "#{@r.first_name} #{@r.last_name}"
    end
  end

  context "age" do
    before(:each) do
      @p = FactoryGirl.create(:icu_player, dob: nil)
    end

    it "should be nil if no dob" do
      @p.age.should be_nil
      @p.age(Date.parse("1900-01-01")).should be_nil
    end

    it "should be zero for date before dob" do
      @p.dob = Date.parse("2011-12-17")
      @p.age(Date.parse("2000-01-01")).should == 0
    end

    it "should be non-negative integer" do
      @p.dob = Date.parse("1955-11-09")
      @p.age(Date.parse("2011-12-17")).should == 56
      @p.age(Date.parse("2012-11-09")).should == 57
    end

    it "should with leap years" do
      @p.dob = Date.parse("2011-02-28")
      @p.age(Date.parse("2012-02-27")).should == 0
      @p.age(Date.parse("2012-02-28")).should == 1
      @p.age(Date.parse("2012-02-29")).should == 1
      @p.dob = Date.parse("2012-02-29")
      @p.age(Date.parse("2013-02-28")).should == 0
      @p.age(Date.parse("2013-03-01")).should == 1
    end
  end
end
