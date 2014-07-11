require 'rails_helper'

describe IcuPlayer do
  context "alternative names" do
    it "should generate SQL for names with no alternatives" do
      expect(IcuPlayer.first_name_like("Liam", "Brady")).to eq("first_name LIKE '%Liam%'")
      expect(IcuPlayer.last_name_like("Orr", "Mark")).to eq("last_name LIKE '%Orr%'")
    end

    it "should generate SQL for names with alternatives" do
      expect(IcuPlayer.first_name_like("Debbie", "Quinn")).to eq("first_name LIKE '%Debbie%' OR first_name LIKE '%Deborah%'")
      expect(IcuPlayer.first_name_like("Tony", "Fox")).to eq("first_name LIKE '%Anthony%' OR first_name LIKE '%Tony%'")
      expect(IcuPlayer.last_name_like("Murphy", "Oissine")).to eq("last_name LIKE '%Murchadha%' OR last_name LIKE '%Murphy%'")
    end

    it "should generate SQL for names with conditional alternatives" do
      expect(IcuPlayer.first_name_like("Sean", "Bradley")).to eq("first_name LIKE '%John%' OR first_name LIKE '%Sean%'")
      expect(IcuPlayer.first_name_like("Sean", "Brady")).to eq("first_name LIKE '%Sean%'")
      expect(IcuPlayer.last_name_like("Quinn", "Debbie")).to eq("last_name LIKE '%Benjamin%' OR last_name LIKE '%Quinn%'")
      expect(IcuPlayer.last_name_like("Quinn", "Mark")).to eq("last_name LIKE '%Quinn%'")
    end

    it "should properly escape values to stop SQL injection" do
      expect(IcuPlayer.last_name_like("\\''; DROP TABLE users; --", "Debbie")).to match(/\\\\''''/)
      expect(IcuPlayer.first_name_like("' or '1'='1", "Quinn")).to match(/''/)
    end
  end

  context "name" do
    before(:each) do
      @p = FactoryGirl.create(:icu_player, title: "IM", club: "Bangor")
      @q = FactoryGirl.create(:icu_player, title: "GM")
      @r = FactoryGirl.create(:icu_player)
    end

    it "no options or single boolean option" do
      expect(@p.name).to eq("#{@p.last_name}, #{@p.first_name}")
      expect(@p.name(true)).to eq("#{@p.last_name}, #{@p.first_name}")
      expect(@p.name(false)).to eq("#{@p.first_name} #{@p.last_name}")
    end

    it "symbolic options" do
      expect(@p.name(:title)).to eq("#{@p.first_name} #{@p.last_name}, IM")
      expect(@p.name(:club)).to eq("#{@p.first_name} #{@p.last_name}, Bangor")
      expect(@p.name(:reversed, :title)).to eq("#{@p.last_name}, #{@p.first_name}, IM")
      expect(@p.name(:title, :brackets)).to eq("#{@p.first_name} #{@p.last_name} (IM)")
      expect(@p.name(:club, :title, :brackets)).to eq("#{@p.first_name} #{@p.last_name} (Bangor, IM)")
      expect(@p.name(:title, :club, :brackets)).to eq("#{@p.first_name} #{@p.last_name} (IM, Bangor)")
      expect(@q.name(:title, :club, :brackets)).to eq("#{@q.first_name} #{@q.last_name} (GM)")
      expect(@r.name(:title, :club, :brackets)).to eq("#{@r.first_name} #{@r.last_name}")
      expect(@p.name(:title, :club)).to eq("#{@p.first_name} #{@p.last_name}, IM, Bangor")
      expect(@q.name(:title, :club)).to eq("#{@q.first_name} #{@q.last_name}, GM")
      expect(@r.name(:title, :club)).to eq("#{@r.first_name} #{@r.last_name}")
    end
  end

  context "age" do
    before(:each) do
      @p = FactoryGirl.create(:icu_player, dob: nil)
    end

    it "should be nil if no dob" do
      expect(@p.age).to be_nil
      expect(@p.age(Date.parse("1900-01-01"))).to be_nil
    end

    it "should be zero for date before dob" do
      @p.dob = Date.parse("2011-12-17")
      expect(@p.age(Date.parse("2000-01-01"))).to eq(0)
    end

    it "should be non-negative integer" do
      @p.dob = Date.parse("1955-11-09")
      expect(@p.age(Date.parse("2011-12-17"))).to eq(56)
      expect(@p.age(Date.parse("2012-11-09"))).to eq(57)
    end

    it "should with leap years" do
      @p.dob = Date.parse("2011-02-28")
      expect(@p.age(Date.parse("2012-02-27"))).to eq(0)
      expect(@p.age(Date.parse("2012-02-28"))).to eq(1)
      expect(@p.age(Date.parse("2012-02-29"))).to eq(1)
      @p.dob = Date.parse("2012-02-29")
      expect(@p.age(Date.parse("2013-02-28"))).to eq(0)
      expect(@p.age(Date.parse("2013-03-01"))).to eq(1)
    end
  end
end
