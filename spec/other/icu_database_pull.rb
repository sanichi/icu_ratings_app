require 'spec_helper'

describe "#get_member" do
  it "should return member details from the main database" do
    details = ICU::Database::Pull.new.get_member(756, "mark.j.l.orr@googlemail.com")
    expect(details).to be_instance_of Hash
    expect(details[:password].length).to eq(32)
    expect(details[:salt].length).to eq(32)
    expect(User::STATUS).to include(details[:status])
    expect(details[:expiry].to_s).to match(/^20\d\d-\d\d-\d\d$/)
  end

  it "should return an error message if appropriate" do
    details = ICU::Database::Pull.new.get_member(1241, "mark.j.l.orr@googlemail.com")
    expect(details.to_s).to match(/expected/)
  end
end
