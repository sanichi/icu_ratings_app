# encoding: UTF-8
require 'rails_helper'

# Sanity check stuff that is provided by icu_name.
module ICU
  describe Name do
    it "the alternatives should be loaded" do
      expect(Name.alt_compilations(:first)).to eq(1)
      expect(Name.alt_compilations(:last)).to eq(1)
      expect(Name.new("Dave", "Hunter").alternatives(:first)).to eq(%w[David])
    end

    it "should handle recent additions to the default set of first name alternatives" do
      expect(Name.new("Douglas", "McCann").match("Dougie", "McCann")).to be true
      expect(Name.new("Edward", "Walsh").match("Ned", "Walsh")).to be true
      expect(Name.new("Michael", "Morgan").match("Míchéal", "Morgan", chars: "US-ASCII")).to be true
    end

    it "should handle recent additions to the default set of last name alternatives" do
      expect(Name.new("Alex", "Lopez").match("Alex", "Astaneh Lopez")).to be true
      expect(Name.new("William", "French").match("William", "Ffrench")).to be true
      expect(Name.new("Mairead", "King").match("Mairead", "O'Siochru")).to be true
    end
  end

  module Util
    class Dummy
      extend AlternativeNames
    end

    describe AlternativeNames do
      it "should be working" do
        expect(Dummy.last_name_like("Murphy", "Oissine")).to eq("last_name LIKE '%Murchadha%' OR last_name LIKE '%Murphy%'")
        expect(Dummy.first_name_like("Pete", "Morriss")).to eq("first_name LIKE '%Pete%' OR first_name LIKE '%Peter%'")
      end
    end
  end
end
