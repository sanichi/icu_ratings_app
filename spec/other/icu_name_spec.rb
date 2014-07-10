# encoding: UTF-8
require 'spec_helper'

# Sanity check stuff that is provided by icu_name.
module ICU
  describe Name do
    it "the alternatives should be loaded" do
      Name.alt_compilations(:first).should == 1
      Name.alt_compilations(:last).should == 1
      Name.new("Dave", "Hunter").alternatives(:first).should == %w[David]
    end

    it "should handle recent additions to the default set of first name alternatives" do
      Name.new("Douglas", "McCann").match("Dougie", "McCann").should be true
      Name.new("Edward", "Walsh").match("Ned", "Walsh").should be true
      Name.new("Michael", "Morgan").match("Míchéal", "Morgan", chars: "US-ASCII").should be true
    end

    it "should handle recent additions to the default set of last name alternatives" do
      Name.new("Alex", "Lopez").match("Alex", "Astaneh Lopez").should be true
      Name.new("William", "French").match("William", "Ffrench").should be true
      Name.new("Mairead", "King").match("Mairead", "O'Siochru").should be true
    end
  end

  module Util
    class Dummy
      extend AlternativeNames
    end

    describe AlternativeNames do
      it "should be working" do
        Dummy.last_name_like("Murphy", "Oissine").should == "last_name LIKE '%Murchadha%' OR last_name LIKE '%Murphy%'"
        Dummy.first_name_like("Pete", "Morriss").should == "first_name LIKE '%Pete%' OR first_name LIKE '%Peter%'"
      end
    end
  end
end
