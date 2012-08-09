require 'spec_helper'

describe RatingList do
  context "date and cut-off" do
    before(:each) do
      @rl = RatingList.new
    end

    it "should have a list date" do
      expect { @rl.save! }.to raise_error
    end

    it "should be on the 1st of the month" do
      @rl.date = Date.new(2012, 1, 2)
      @rl.cut_off = Date.new(2012, 1, 15)
      expect { @rl.save! }.to raise_error(/1st day of month/)
      @rl.date = Date.new(2012, 1, 1)
      expect { @rl.save! }.not_to raise_error
    end

    it "should not have a date in the future" do
      @rl.date = Date.today.end_of_year.tomorrow
      @rl.cut_off = @rl.date.advance(days: 14)
      expect { @rl.save! }.to raise_error(/on or before/)
      @rl.date = Date.new(2012, 5, 1)
      @rl.cut_off = @rl.date.advance(days: 14)
      expect { @rl.save! }.not_to raise_error
    end

    it "should not be before Jan 2012 (the first list of the new system)" do
      @rl.date = Date.new(2011, 9, 1)
      @rl.cut_off = Date.new(2011, 9, 15)
      expect { @rl.save! }.to raise_error(/on or after/)
      @rl.date = Date.new(2012, 1, 1)
      @rl.cut_off = Date.new(2012, 1, 15)
      expect { @rl.save! }.not_to raise_error
    end

    it "should have same months for date and cut-off" do
      @rl.date = Date.new(2012, 5, 1)
      @rl.cut_off = Date.new(2012, 6, 1)
      expect { @rl.save! }.to raise_error(/same month/)
      @rl.cut_off = Date.new(2012, 5, 15)
      expect { @rl.save! }.not_to raise_error
    end
  end

  context "#publish" do
    before(:each) do
      @legacy = load_old_ratings
      @subs = load_subscriptions
      @icu_players = load_icu_players
      RatingList.auto_populate
      @u = FactoryGirl.create(:user, role: "officer")
      @t1, @t3 = %w{kilkenny_masters_2011.tab armstrong_2012_with_bom.tab}.map do |f|
        t = test_tournament(f, @u.id)
        t.move_stage("ready", @u)
        t.move_stage("queued", @u)
        t.rate!
        t
      end
      @l1 = RatingList.find_by_date(Date.new(2012, 1, 1))
      @l2 = RatingList.find_by_date(Date.new(2012, 5, 1))
    end

    it "should be setup OK" do
      OldRating.count.should be > 0
      Subscription.count.should == @subs.size
      RatingList.count.should be >= 2
      IcuRating.count.should == 0
      @t1.stage.should == "rated"
      @t3.stage.should == "rated"
      @l1.should_not be_nil
      @l1.publications.should be_empty
      @l2.should_not be_nil
      @l2.publications.should be_empty
    end

    it "should publish lists" do
      pub_date = Date.new(2012, 1, 16)
      pay_date = Date.new(2012, 2, 1)
      @l1.publish(pub_date)
      subs1 = @subs.values.find_all{ |s| s.category == "lifetime" || (s.season == "2011-12" && (!s.pay_date || s.pay_date < pay_date)) }.count
      IcuRating.count.should == subs1
      @l1.publications.size.should == 1
      p = @l1.publications[0]
      p.total.should == subs1
      p.creates.should == subs1
      p.remains.should == 0
      p.updates.should == 0
      p.deletes.should == 0

      # Player who played in tournament 1 and subscribed in time.
      player = @t1.players.find_by_icu_id(159)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 159)
      rating.should_not be_nil
      rating.rating.should == player.new_rating
      rating.full.should == player.new_full
      rating.original_rating.should == player.new_rating
      rating.original_full.should == player.new_full

      # Player who played in tournament 1 but didn't subscribe in time.
      player = @t1.players.find_by_icu_id(456)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 456)
      rating.should be_nil

      # Player who played in tournament 1 but didn't subscribe at all.
      player = @t1.players.find_by_icu_id(5722)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 5722)
      rating.should be_nil

      # Player who didn't play in tournament 1 but does have a subscription.
      player = @t1.players.find_by_icu_id(1350)
      player.should be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 1350)
      rating.should_not be_nil
      rating.rating.should == @legacy[1350].rating
      rating.full.should == @legacy[1350].full
      rating.original_rating.should == @legacy[1350].rating
      rating.original_full.should == @legacy[1350].full

      # Player who didn't play in tournament 1 and has no subscription.
      player = @t1.players.find_by_icu_id(6236)
      player.should be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 6236)
      rating.should be_nil

      # Re-publishing the list a few days later without any changes.
      pub_date = Date.new(2012, 1, 19)
      @l1.publish(pub_date)
      @l1.publications.size.should == 2
      p = @l1.publications[1]
      p.total.should == subs1
      p.creates.should == 0
      p.remains.should == subs1
      p.updates.should == 0
      p.deletes.should == 0
      IcuRating.where("rating != original_rating").count.should == 0

      # Simulate adding a subscription and re-publishing the list within January.
      @subs[5722] = FactoryGirl.create(:subscription, icu_id: 5722, category: "offline", season: "2011-12", pay_date: "2012-01-22")
      subs1 += 1
      pub_date = Date.new(2012, 1, 23)
      @l1.publish(pub_date)
      @l1.publications.size.should == 3
      p = @l1.publications[2]
      p.total.should == subs1
      p.creates.should == 1
      p.remains.should == subs1 - 1
      p.updates.should == 0
      p.deletes.should == 0
      IcuRating.where("rating != original_rating").count.should == 0

      # Simulate a legacy rating change and a re-publication still within January.
      legacy = @legacy[1350]
      legacy.rating += 1
      legacy.save
      pub_date = Date.new(2012, 1, 24)
      @l1.publish(pub_date)
      @l1.publications.size.should == 4
      p = @l1.publications[3]
      p.total.should == subs1
      p.creates.should == 0
      p.remains.should == subs1 - 1
      p.updates.should == 1
      p.deletes.should == 0
      IcuRating.where("rating != original_rating").count.should == 0

      # Simulate another legacy rating change and a re-publication after January.
      legacy = @legacy[1350]
      legacy.rating += 1
      legacy.save
      pub_date = Date.new(2012, 2, 1)
      @l1.publish(pub_date)
      @l1.publications.size.should == 5
      p = @l1.publications[4]
      p.total.should == subs1
      p.creates.should == 0
      p.remains.should == subs1 - 1
      p.updates.should == 1
      p.deletes.should == 0
      IcuRating.where("rating != original_rating").count.should == 1
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 1350)
      rating.should_not be_nil
      rating.rating.should == @legacy[1350].rating
      rating.full.should == @legacy[1350].full
      rating.original_rating.should == @legacy[1350].rating - 1
      rating.original_full.should == @legacy[1350].full

      # Publish the second list which includes the second tournament.
      pub_date = Date.new(2012, 5, 16)
      pay_date = Date.new(2012, 6, 1)
      @l2.publish(pub_date)
      subs2 = @subs.values.find_all{ |s| s.category == "lifetime" || (s.season == "2011-12" && (!s.pay_date || s.pay_date < pay_date)) }.count
      IcuRating.count.should == subs1 + subs2
      @l2.publications.size.should == 1
      p = @l2.publications[0]
      p.total.should == subs2
      p.creates.should == subs2
      p.remains.should == 0
      p.updates.should == 0
      p.deletes.should == 0

      # Player who played in tournament 2 and subscribed in time.
      player = @t3.players.find_by_icu_id(159)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 159)
      rating.should_not be_nil
      rating.rating.should == player.new_rating
      rating.full.should == player.new_full
      rating.original_rating.should == player.new_rating
      rating.original_full.should == player.new_full

      # Another player who played in tournament 2 and subscribed in time.
      player = @t3.players.find_by_icu_id(6897)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 6897)
      rating.should_not be_nil
      rating.rating.should == player.new_rating
      rating.full.should == player.new_full
      rating.original_rating.should == player.new_rating
      rating.original_full.should == player.new_full

      # Player who didn't play in either tournament but has a subscription.
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 1350)
      rating.should_not be_nil
      rating.rating.should == @legacy[1350].rating
      rating.full.should == @legacy[1350].full

      # Simulate adding and rating a new tournament.
      @t2 = test_tournament("intermediate_2012.tab", @u.id)
      @t2.move_stage("ready", @u)
      @t2.move_stage("queued", @u)
      @t3.reload
      @t3.rorder.should be > @t2.rorder

      # Since this new tournament comes before @t3, we have to rerate both.
      @t2.rate!
      @t3.rate!

      # Now republish the list but after the publication month has expired (so original ratings are not altered).
      pub_date = Date.new(2012, 6, 1)
      @l2.publish(pub_date)
      @l2.publications.size.should == 2
      p = @l2.publications[1]
      p.total.should == subs2
      puts p.report
      p.creates.should == 0
      p.remains.should == subs2 - 2
      p.updates.should == 2
      p.deletes.should == 0

      # Player whose only games are in @t2.
      player = @t2.players.find_by_icu_id(1350)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 1350)
      rating.should_not be_nil
      rating.rating.should == player.new_rating
      rating.full.should == player.new_full
      rating.original_rating.should_not == player.new_rating
      rating.original_rating.should == @legacy[1350].rating
      rating.original_full.should == @legacy[1350].full

      # Player whose last games are in @t3.
      player = @t3.players.find_by_icu_id(159)
      player.should_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 159)
      rating.should_not be_nil
      rating.rating.should == player.new_rating
      rating.full.should == player.new_full
      rating.original_rating.should_not == player.new_rating
    end
  end
end
