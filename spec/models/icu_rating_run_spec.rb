require 'rails_helper'

describe ICU::RatingRun do
  context "basic errors" do
    before(:each) do
      @flag = RatingRun.flag
      File.unlink(@flag) if File.exists?(@flag)
    end

    it "can't run without a flag" do
      ICU::RatingRun.new.rate_all
      expect(Failure.count).to eq(1)
      f = Failure.first
      expect(f.details).to match(/no flag/)
    end

    it "can't run without an ID in the flag" do
      File.open(@flag, "w") { }
      ICU::RatingRun.new.rate_all
      expect(Failure.count).to eq(1)
      f = Failure.first
      expect(f.details).to match(/no ID/)
    end

    it "can't run without an object matching the ID" do
      File.open(@flag, "w") { |f| f.write 1 }
      ICU::RatingRun.new.rate_all
      expect(Failure.count).to eq(1)
      f = Failure.first
      expect(f.details).to match(/no object/)
    end
  end

  context "rate all" do
    before(:each) do
      tests = %w[isle_of_man_2007.csv junior_championships_u19_2010.txt kilbunny_masters_2011.tab]
      load_icu_players_for(tests)
      load_old_ratings
      @u = FactoryGirl.create(:user, role: "officer")
      @t1, @t2, @t3 = tests.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u) unless f == "kilbunny_masters_2011.tab"
        t
      end
      [@t1, @t2, @t3].each { |o| o.reload }
      @rating_run = RatingRun.create!(user_id: @u.id, start_tournament_id: @t1.id)
      @flag = RatingRun.flag
    end

    it "success" do
      expect(@rating_run.status).to eq("waiting")
      expect(File.exists?(@flag)).to be true

      ICU::RatingRun.new.rate_all

      expect(Failure.count).to eq(0)
      expect(File.exists?(@flag)).to be false

      @rating_run.reload
      expect(@rating_run.status).to eq("finished")
      expect(@rating_run.report).to match /Rating 2 tournaments/
      expect(@rating_run.report).to match /1\s+\d+\/\d+\s+#{@t1.name}/
      expect(@rating_run.report).to match /2\s+\d+\/\d+\s+#{@t2.name}/
      expect(@rating_run.report).to match /Finished/

      [@t1, @t2].each { |o| o.reload }
      expect(@t1.stage).to eq("rated")
      expect(@t1.stage).to eq("rated")
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(1)

      expect(Tournament.next_for_rating).to be_nil
    end

    it "failure due to tournament being rated" do
      @t1.rate!

      ICU::RatingRun.new.rate_all

      expect(Failure.count).to eq(0)
      expect(File.exists?(@flag)).to be false

      @rating_run.reload
      expect(@rating_run.status).to eq("error")
      expect(@rating_run.report).to match /Error.+next for rating/

      [@t1, @t2].each { |o| o.reload }
      expect(@t1.stage).to eq("rated")
      expect(@t2.stage).to eq("queued")
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(0)

      expect(Tournament.next_for_rating).to eq(@t2)
    end

    it "failure due to tournament being queued" do
      @t3.move_stage("queued", @u)

      ICU::RatingRun.new.rate_all

      expect(Failure.count).to eq(0)
      expect(File.exists?(@flag)).to be false

      @rating_run.reload
      expect(@rating_run.status).to eq("error")
      expect(@rating_run.report).to match /Error.+expected.+finish/

      [@t1, @t2, @t3].each { |o| o.reload }
      expect(@t1.stage).to eq("rated")
      expect(@t2.stage).to eq("rated")
      expect(@t3.stage).to eq("queued")
      expect(@t1.reratings).to eq(1)
      expect(@t2.reratings).to eq(1)
      expect(@t3.reratings).to eq(0)

      expect(Tournament.next_for_rating).to eq(@t3)
    end

    it "failure due to change in status" do
      p = @t1.players.find_by_last_name("Cafolla")
      p.icu_id = p.icu_id + 1
      p.save
      @t1.reload
      expect(@t1.status_ok?).to be false

      ICU::RatingRun.new.rate_all

      expect(Failure.count).to eq(0)
      expect(File.exists?(@flag)).to be false

      @rating_run.reload
      expect(@rating_run.status).to eq("error")
      expect(@rating_run.report).to match /Error.+status.+not suitable/

      [@t1, @t2].each { |o| o.reload }
      expect(@t1.stage).to eq("queued")
      expect(@t2.stage).to eq("queued")
      expect(@t1.reratings).to eq(0)
      expect(@t2.reratings).to eq(0)

      expect(Tournament.next_for_rating).to eq(@t1)
    end

    it "failure due to change in order" do
      @t1.start = @t2.start + 10
      @t1.finish = @t2.finish + 10
      @t1.save

      ICU::RatingRun.new.rate_all

      expect(Failure.count).to eq(0)
      expect(File.exists?(@flag)).to be false

      @rating_run.reload
      expect(@rating_run.status).to eq("error")
      expect(@rating_run.report).to match /Error.+expected.+rating order/

      [@t1, @t2].each { |o| o.reload }
      expect(@t1.stage).to eq("queued")
      expect(@t2.stage).to eq("queued")
      expect(@t1.reratings).to eq(0)
      expect(@t2.reratings).to eq(0)

      expect(Tournament.next_for_rating).to eq(@t2)
    end
  end
end