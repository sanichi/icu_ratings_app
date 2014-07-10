require 'rails_helper'

describe FideRating do
  context "validation" do
    before(:each) do
      @p1 = FidePlayer.create(first_name: "Mark", last_name: "Orr", fed: "IRL", born: 1955, gender: "M")
      @p2 = FidePlayer.create(first_name: "Gear", last_name: "Uil", fed: "IRL", born: 1964, gender: "F")
    end

    it "test players should be valid" do
      expect(@p1.valid?).to be true
      expect(@p2.valid?).to be true
      expect(@p1.fide_ratings.size).to eq(0)
      expect(@p2.fide_ratings.size).to eq(0)
    end

    it "rating lists must be the 1st of the month" do
      expect { @p1.fide_ratings.create!(list: Date.civil(2010, 12, 2), rating: 2200, games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /1st day/)
      expect { @p1.fide_ratings.create!(list: Date.civil(2010, 12, 1), rating: 2200, games: 0) }.to_not raise_error
    end

    it "rating lists must be after a certain date" do
      expect { @p1.fide_ratings.create!(list: Date.civil(1949, 12, 1), rating: 2200, games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /on or after/)
      expect { @p1.fide_ratings.create!(list: Date.civil(1950,  1, 1), rating: 2200, games: 0) }.to_not raise_error
    end

    it "rating lists are unique for reach player" do
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 2200, games: 0) }.to_not raise_error
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 2, 1), rating: 2200, games: 0) }.to_not raise_error
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 2, 1), rating: 2200, games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /taken/)
      expect { @p2.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 1600, games: 0) }.to_not raise_error
      expect { @p2.fide_ratings.create!(list: Date.civil(2011, 2, 1), rating: 1600, games: 0) }.to_not raise_error
      expect { @p2.fide_ratings.create!(list: Date.civil(2011, 2, 1), rating: 1600, games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /taken/)
      expect(@p1.fide_ratings.size).to eq(2)
      expect(@p2.fide_ratings.size).to eq(2)
    end

    it "ratings should be within a certain range" do
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 0,    games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /greater/)
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 3000, games: 0) }.to raise_error(ActiveRecord::RecordInvalid, /less/)
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 2000, games: 0) }.to_not raise_error
    end

    it "games should be within a certain range" do
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 2200, games: -1) }.to raise_error(ActiveRecord::RecordInvalid, /greater/)
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 2200, games: 999) }.to raise_error(ActiveRecord::RecordInvalid, /less/)
      expect { @p1.fide_ratings.create!(list: Date.civil(2011, 1, 1), rating: 2000, games: 0) }.to_not raise_error
    end
  end
end
