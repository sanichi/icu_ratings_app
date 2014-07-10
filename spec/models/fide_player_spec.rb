require 'spec_helper'

describe FidePlayer do
  context "validation" do
    before(:each) do
      @m = IcuPlayer.create(first_name: "M.", last_name: "Orr", deceased: false, joined: "1980-01-01")
    end

    it "ICU player IDs, if they exist, should be unique" do
      expect { FidePlayer.create!(first_name: "P.", last_name: "Ure", fed: "POL", gender: "M") }.to_not raise_error
      expect { FidePlayer.create!(first_name: "Q.", last_name: "Cho", fed: "CHN", gender: "F") }.to_not raise_error
      expect { FidePlayer.create!(first_name: "J.", last_name: "Orr", fed: "IRL", gender: "M", icu_id: @m.id) }.to_not raise_error
      expect { FidePlayer.create!(first_name: "G.", last_name: "Sax", fed: "HUN", gender: "M", icu_id: @m.id) }.to raise_error(ActiveRecord::RecordInvalid, /taken/)
    end
  end

  context "name" do
    before(:each) do
      @p = FactoryGirl.create(:fide_player, title: "IM")
      @r = FactoryGirl.create(:fide_player)
    end

    it "no options or single boolean option" do
      expect(@p.name).to eq("#{@p.last_name}, #{@p.first_name}")
      expect(@p.name(true)).to eq("#{@p.last_name}, #{@p.first_name}")
      expect(@p.name(false)).to eq("#{@p.first_name} #{@p.last_name}")
    end

    it "symbolic options" do
      expect(@p.name(:title)).to eq("#{@p.first_name} #{@p.last_name}, IM")
      expect(@p.name(:reversed, :title)).to eq("#{@p.last_name}, #{@p.first_name}, IM")
      expect(@p.name(:title, :brackets)).to eq("#{@p.first_name} #{@p.last_name} (IM)")
      expect(@p.name(:title, :brackets, :reversed)).to eq("#{@p.last_name}, #{@p.first_name} (IM)")
    end
  end
end
