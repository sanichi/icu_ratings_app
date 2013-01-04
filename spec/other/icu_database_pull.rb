require 'spec_helper'

describe "#get_member" do
  it "should return member details from the main database" do
    details = ICU::Database::Pull.new.get_member(756, "mark.j.l.orr@googlemail.com")
    details.should be_instance_of Hash
    details[:password].length.should == 32
    details[:salt].length.should == 32
    User::STATUS.should include(details[:status])
    details[:expiry].to_s.should match(/^20\d\d-\d\d-\d\d$/)
  end

  it "should return an error message if appropriate" do
    details = ICU::Database::Pull.new.get_member(1241, "mark.j.l.orr@googlemail.com")
    details.to_s.should match(/expected/)
  end
end
