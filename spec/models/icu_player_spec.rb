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
      @p = Factory(:icu_player)
    end

    it "reveresed (the default) and normal" do
      @p.name.should == "#{@p.last_name}, #{@p.first_name}"
      @p.name(false).should == "#{@p.first_name} #{@p.last_name}"
    end
  end
end
