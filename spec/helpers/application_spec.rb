require 'spec_helper'

describe "sign" do
  it "should truncate and add a sign" do
    helper.sign(1234).should == "+1234"
    helper.sign(1.9).should == "+2"
    helper.sign(1.1).should == "+1"
    helper.sign(1).should == "+1"
    helper.sign(0.9).should == "+1"
    helper.sign(0.1).should == "+0"
    helper.sign(0).should == "+0"
    helper.sign(-0.1).should == "-0"
    helper.sign(-0.9).should == "-1"
    helper.sign(-1).should == "-1"
    helper.sign(-999.4999).should == "-999"
    helper.sign(-999.5).should == "-1000"
  end

  it "optional arguments" do
    helper.sign(1, space: true).should == "+ 1"
    helper.sign(0.1, space: true).should == "+ 0"
    helper.sign(0, space: true).should == "+ 0"
    helper.sign(-0.1, space: true).should == "- 0"
    helper.sign(-1, space: true).should == "- 1"
  end
end
