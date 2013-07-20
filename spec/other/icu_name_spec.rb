# encoding: UTF-8
require 'spec_helper'

module ICU
  describe Name do
    before(:all) do
      # Using the class seems to be required to cause the alternatives to load before the first test if they haven't already.
      Name.new("Mark", "Orr")
    end

    it "should handle new additions to alternative_first_names" do
      Name.new("Douglas", "McCann").match("Dougie", "McCann").should be_true
      Name.new("Edward", "Walsh").match("Ned", "Walsh").should be_true
      Name.new("Michael", "Morgan").match("Míchéal", "Morgan", chars: "US-ASCII").should be_true
    end

    it "should handle new additions to alternative_last_names" do
      Name.new("Alex", "Lopez").match("Alex", "Astaneh Lopez").should be_true
      Name.new("William", "French").match("William", "Ffrench").should be_true
      Name.new("Mairead", "King").match("Mairead", "O'Siochru").should be_true
    end
  end
end
