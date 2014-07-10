# encoding: UTF-8
require 'spec_helper'

describe "sign" do
  it "should truncate and add a sign" do
    expect(helper.sign(1234)).to eq("+1234")
    expect(helper.sign(1.9)).to eq("+2")
    expect(helper.sign(1.1)).to eq("+1")
    expect(helper.sign(1)).to eq("+1")
    expect(helper.sign(0.9)).to eq("+1")
    expect(helper.sign(0.1)).to eq("+0")
    expect(helper.sign(0)).to eq("0")
    expect(helper.sign(0.0)).to eq("0")
    expect(helper.sign(-0.1)).to eq("−0")
    expect(helper.sign(-0.9)).to eq("−1")
    expect(helper.sign(-1)).to eq("−1")
    expect(helper.sign(-999.4999)).to eq("−999")
    expect(helper.sign(-999.5)).to eq("−1000")
  end

  it "optional arguments" do
    expect(helper.sign(1, space: true)).to eq("+ 1")
    expect(helper.sign(0.1, space: true)).to eq("+ 0")
    expect(helper.sign(0, space: true)).to eq("+ 0")
    expect(helper.sign(0.0, space: true)).to eq("+ 0")
    expect(helper.sign(-0.1, space: true)).to eq("− 0")
    expect(helper.sign(-1, space: true)).to eq("− 1")
  end
end
