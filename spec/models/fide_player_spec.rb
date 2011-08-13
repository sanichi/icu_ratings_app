require 'spec_helper'

describe FidePlayer do
  context "validation" do
    before(:each) do
      @m = IcuPlayer.create(:first_name => 'M.', :last_name => 'Orr', :deceased => false, :joined => '1980-01-01')
      @id = @m.id
    end

    it "ICU player IDs, if they exist, should be unique" do
      lambda { FidePlayer.create!(:first_name => 'P.', :last_name => 'Ure', :fed => 'POL', :gender => 'M') }.should_not raise_error
      lambda { FidePlayer.create!(:first_name => 'Q.', :last_name => 'Cho', :fed => 'CHN', :gender => 'F') }.should_not raise_error
      lambda { FidePlayer.create!(:first_name => 'J.', :last_name => 'Orr', :fed => 'IRL', :gender => 'M', :icu_id => @id) }.should_not raise_error
      lambda { FidePlayer.create!(:first_name => 'G.', :last_name => 'Sax', :fed => 'HUN', :gender => 'M', :icu_id => @id) }.should raise_error(ActiveRecord::RecordInvalid, /taken/)
    end
  end
end
