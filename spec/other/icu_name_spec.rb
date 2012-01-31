require 'spec_helper'

module ICU
  describe Name do
    it "should handle new additions to alternative_first_names" do
      Name.new('Douglas', 'McCann').match('Dougie', 'McCann').should be_true
      Name.new('Edward', 'Walsh').match('Ned', 'Walsh').should be_true
    end
  end
end
