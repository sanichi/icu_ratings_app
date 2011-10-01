require 'spec_helper'

describe FideRating do
  context "validation" do
    before(:each) do
      @p1 = FidePlayer.create(first_name: "Mark", last_name: "Orr", fed: "IRL", born: 1955, gender: "M")
      @p2 = FidePlayer.create(first_name: "Gear", last_name: "Uil", fed: "IRL", born: 1964, gender: "F")
    end

    it "test players should be valid" do
      @p1.valid?.should be_true
      @p2.valid?.should be_true
      @p1.fide_ratings.size.should == 0
      @p2.fide_ratings.size.should == 0
    end

    it "rating periods must be the 1st of the month" do
      lambda { @p1.fide_ratings.create!(period: Date.civil(2010, 12, 2), rating: 2200, games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /1st day/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(2010, 12, 1), rating: 2200, games: 0) }.should_not raise_error
    end

    it "rating periods must be after a certain date" do
      lambda { @p1.fide_ratings.create!(period: Date.civil(1949, 12, 1), rating: 2200, games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /on or after/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(1950,  1, 1), rating: 2200, games: 0) }.should_not raise_error
    end

    it "rating periods are unique for reach player" do
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 2200, games: 0) }.should_not raise_error
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 2, 1), rating: 2200, games: 0) }.should_not raise_error
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 2, 1), rating: 2200, games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /taken/)
      lambda { @p2.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 1600, games: 0) }.should_not raise_error
      lambda { @p2.fide_ratings.create!(period: Date.civil(2011, 2, 1), rating: 1600, games: 0) }.should_not raise_error
      lambda { @p2.fide_ratings.create!(period: Date.civil(2011, 2, 1), rating: 1600, games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /taken/)
      @p1.fide_ratings.size.should == 2
      @p2.fide_ratings.size.should == 2
    end

    it "ratings should be within a certain range" do
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 0,    games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /greater/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 3000, games: 0) }.should raise_error(ActiveRecord::RecordInvalid, /less/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 2000, games: 0) }.should_not raise_error
    end

    it "games should be within a certain range" do
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 2200, games: -1) }.should raise_error(ActiveRecord::RecordInvalid, /greater/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 2200, games: 999) }.should raise_error(ActiveRecord::RecordInvalid, /less/)
      lambda { @p1.fide_ratings.create!(period: Date.civil(2011, 1, 1), rating: 2000, games: 0) }.should_not raise_error
    end
  end
end
