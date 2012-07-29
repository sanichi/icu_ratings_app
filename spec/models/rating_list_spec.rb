require 'spec_helper'

describe RatingList do
  before(:each) do
    @rl = RatingList.new
  end

  it "should have a list date" do
    expect { @rl.save! }.to raise_error
  end

  it "should be on the 1st of the month" do
    @rl.date = Date.new(2012, 1, 2)
    expect { @rl.save! }.to raise_error(/1st day of month/)
    @rl.date = Date.new(2012, 1, 1)
    expect { @rl.save! }.not_to raise_error
  end

  it "should not have a date in the future" do
    @rl.date = Date.today.end_of_year.tomorrow
    expect { @rl.save! }.to raise_error(/on or before/)
    @rl.date = Date.new(2012, 5, 1)
    expect { @rl.save! }.not_to raise_error
  end

  it "should not be before Jan 2012 (the first list of the new system)" do
    @rl.date = Date.new(2011, 9, 1)
    expect { @rl.save! }.to raise_error(/on or after/)
    @rl.date = Date.new(2012, 1, 1)
    expect { @rl.save! }.not_to raise_error
  end
end
