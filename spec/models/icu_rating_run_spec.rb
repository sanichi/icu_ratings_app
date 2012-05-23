require 'spec_helper'

describe ICU::RatingRun do
  context "basic errors" do
    before(:each) do
      @flag = RatingRun.flag
      File.unlink(@flag) if File.exists?(@flag)
    end

    it "can't run without a flag" do
      ICU::RatingRun.new.rate_all
      Failure.count.should == 1
      f = Failure.first
      f.details.should match(/no flag/)
    end

    it "can't run without an ID in the flag" do
      File.open(@flag, "w") { }
      ICU::RatingRun.new.rate_all
      Failure.count.should == 1
      f = Failure.first
      f.details.should match(/no ID/)
    end

    it "can't run without an object matching the ID" do
      File.open(@flag, "w") { |f| f.write 1 }
      ICU::RatingRun.new.rate_all
      Failure.count.should == 1
      f = Failure.first
      f.details.should match(/no object/)
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
      @rating_run.status.should == "waiting"
      File.exists?(@flag).should be_true

      ICU::RatingRun.new.rate_all

      Failure.count.should == 0
      File.exists?(@flag).should be_false

      @rating_run.reload
      @rating_run.status.should == "finished"
      @rating_run.report.should match /Rating 2 tournaments/
      @rating_run.report.should match /1 #{@t1.name}/
      @rating_run.report.should match /2 #{@t2.name}/
      @rating_run.report.should match /Finished/

      [@t1, @t2].each { |o| o.reload }
      @t1.stage.should == "rated"
      @t1.stage.should == "rated"
      @t1.reratings.should == 1
      @t2.reratings.should == 1

      Tournament.next_for_rating.should be_nil
    end

    it "failure due to tournament being rated" do
      @t1.rate!

      ICU::RatingRun.new.rate_all

      Failure.count.should == 0
      File.exists?(@flag).should be_false

      @rating_run.reload
      @rating_run.status.should == "error"
      @rating_run.report.should match /Error.+next for rating/

      [@t1, @t2].each { |o| o.reload }
      @t1.stage.should == "rated"
      @t2.stage.should == "queued"
      @t1.reratings.should == 1
      @t2.reratings.should == 0

      Tournament.next_for_rating.should == @t2
    end

    it "failure due to tournament being queued" do
      @t3.move_stage("queued", @u)

      ICU::RatingRun.new.rate_all

      Failure.count.should == 0
      File.exists?(@flag).should be_false

      @rating_run.reload
      @rating_run.status.should == "error"
      @rating_run.report.should match /Error.+expected.+finish/

      [@t1, @t2, @t3].each { |o| o.reload }
      @t1.stage.should == "rated"
      @t2.stage.should == "rated"
      @t3.stage.should == "queued"
      @t1.reratings.should == 1
      @t2.reratings.should == 1
      @t3.reratings.should == 0

      Tournament.next_for_rating.should == @t3
    end

    it "failure due to change in status" do
      p = @t1.players.find_by_last_name("Cafolla")
      p.icu_id = p.icu_id + 1
      p.save
      @t1.reload
      @t1.status_ok?.should be_false

      ICU::RatingRun.new.rate_all

      Failure.count.should == 0
      File.exists?(@flag).should be_false

      @rating_run.reload
      @rating_run.status.should == "error"
      @rating_run.report.should match /Error.+status.+not suitable/

      [@t1, @t2].each { |o| o.reload }
      @t1.stage.should == "queued"
      @t2.stage.should == "queued"
      @t1.reratings.should == 0
      @t2.reratings.should == 0

      Tournament.next_for_rating.should == @t1
    end

    it "failure due to change in order" do
      @t1.start = @t2.start + 10
      @t1.finish = @t2.finish + 10
      @t1.save

      ICU::RatingRun.new.rate_all

      Failure.count.should == 0
      File.exists?(@flag).should be_false

      @rating_run.reload
      @rating_run.status.should == "error"
      @rating_run.report.should match /Error.+expected.+rating order/

      [@t1, @t2].each { |o| o.reload }
      @t1.stage.should == "queued"
      @t2.stage.should == "queued"
      @t1.reratings.should == 0
      @t2.reratings.should == 0

      Tournament.next_for_rating.should == @t2
    end
  end
end