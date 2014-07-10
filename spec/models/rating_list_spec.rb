require 'rails_helper'

describe RatingList do
  context "dates" do
    it "should have it's dates set" do
      l = RatingList.new
      expect { l.save! }.to raise_error
    end

    it "should have a date on the 1st of the month" do
      l = FactoryGirl.build(:rating_list, date: Date.new(2012, 1, 2))
      expect { l.save! }.to raise_error(/1st day of month/)
      l.date = l.date.beginning_of_month
      expect { l.save! }.to_not raise_error
    end

    it "should not have a date in the future" do
      expect { FactoryGirl.create(:rating_list, date: Date.today.end_of_year.tomorrow) }.to raise_error(/on or before/)
    end

    it "should not be before Jan 2012 (the first list of the new system)" do
      expect { FactoryGirl.create(:rating_list, date: Date.new(2011, 9, 1)) }.to raise_error(/on or after/)
    end

    it "should have same month for date and tournament cut-off" do
      d = Date.new(2012, 5, 1)
      l = FactoryGirl.build(:rating_list, date: d, tournament_cut_off: d.advance(months: 1))
      expect { l.save! }.to raise_error(/same month/)
      l = FactoryGirl.build(:rating_list, date: d, tournament_cut_off: d.yesterday)
      expect { l.save! }.to raise_error(/same month/)
      l.tournament_cut_off = d.change(day: 16)
      expect { l.save! }.to_not raise_error
    end

    it "should have same month or next month for and payment cut-off" do
      d = Date.new(2012, 5, 1)
      l = FactoryGirl.build(:rating_list, date: d, payment_cut_off: d.advance(months: 2))
      expect { l.save! }.to raise_error(/same month or next/)
      l.payment_cut_off = d.yesterday
      expect { l.save! }.to raise_error(/same month or next/)
      l.payment_cut_off = d.advance(days: 40)
      expect { l.save! }.to_not raise_error
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
      expect(OldRating.count).to be > 0
      expect(Subscription.count).to eq(@subs.size)
      expect(RatingList.count).to be >= 2
      expect(IcuRating.count).to eq(0)
      expect(@t1.stage).to eq("rated")
      expect(@t3.stage).to eq("rated")
      expect(@l1).to_not be_nil
      expect(@l1.publications).to be_empty
      expect(@l2).to_not be_nil
      expect(@l2.publications).to be_empty
    end

    it "should publish lists" do
      pub_date = Date.new(2012, 1, 16)
      pay_date = Date.new(2012, 2, 1)
      @l1.publish(pub_date)
      subs1 = @subs.values.find_all{ |s| s.category == "lifetime" || (s.season == "2011-12" && (!s.pay_date || s.pay_date < pay_date)) }.count
      expect(IcuRating.count).to eq(subs1)
      expect(@l1.publications.size).to eq(1)
      p = @l1.publications[0]
      expect(p.total).to eq(subs1)
      expect(p.creates).to eq(subs1)
      expect(p.remains).to eq(0)
      expect(p.updates).to eq(0)
      expect(p.deletes).to eq(0)

      # Player who played in tournament 1 and subscribed in time.
      player = @t1.players.find_by_icu_id(159)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 159)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(player.new_rating)
      expect(rating.full).to eq(player.new_full)
      expect(rating.original_rating).to eq(player.new_rating)
      expect(rating.original_full).to eq(player.new_full)

      # Player who played in tournament 1 but didn't subscribe in time.
      player = @t1.players.find_by_icu_id(456)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 456)
      expect(rating).to be_nil

      # Player who played in tournament 1 but didn't subscribe at all.
      player = @t1.players.find_by_icu_id(5722)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 5722)
      expect(rating).to be_nil

      # Player who didn't play in tournament 1 but does have a subscription.
      player = @t1.players.find_by_icu_id(1350)
      expect(player).to be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 1350)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(@legacy[1350].rating)
      expect(rating.full).to eq(@legacy[1350].full)
      expect(rating.original_rating).to eq(@legacy[1350].rating)
      expect(rating.original_full).to eq(@legacy[1350].full)

      # Player who didn't play in tournament 1 and has no subscription.
      player = @t1.players.find_by_icu_id(6236)
      expect(player).to be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 6236)
      expect(rating).to be_nil

      # Re-publishing the list a few days later without any changes.
      pub_date = Date.new(2012, 1, 19)
      @l1.publish(pub_date)
      expect(@l1.publications.size).to eq(2)
      p = @l1.publications[1]
      expect(p.total).to eq(subs1)
      expect(p.creates).to eq(0)
      expect(p.remains).to eq(subs1)
      expect(p.updates).to eq(0)
      expect(p.deletes).to eq(0)
      expect(IcuRating.where("rating != original_rating").count).to eq(0)

      # Simulate adding a subscription and re-publishing the list within January.
      @subs[5722] = FactoryGirl.create(:subscription, icu_id: 5722, category: "offline", season: "2011-12", pay_date: "2012-01-22")
      subs1 += 1
      pub_date = Date.new(2012, 1, 23)
      @l1.publish(pub_date)
      expect(@l1.publications.size).to eq(3)
      p = @l1.publications[2]
      expect(p.total).to eq(subs1)
      expect(p.creates).to eq(1)
      expect(p.remains).to eq(subs1 - 1)
      expect(p.updates).to eq(0)
      expect(p.deletes).to eq(0)
      expect(IcuRating.where("rating != original_rating").count).to eq(0)

      # Simulate a legacy rating change and a re-publication still within January.
      legacy = @legacy[1350]
      legacy.rating += 1
      legacy.save
      pub_date = Date.new(2012, 1, 24)
      @l1.publish(pub_date)
      expect(@l1.publications.size).to eq(4)
      p = @l1.publications[3]
      expect(p.total).to eq(subs1)
      expect(p.creates).to eq(0)
      expect(p.remains).to eq(subs1 - 1)
      expect(p.updates).to eq(1)
      expect(p.deletes).to eq(0)
      expect(IcuRating.where("rating != original_rating").count).to eq(0)

      # Simulate another legacy rating change and a re-publication after January.
      legacy = @legacy[1350]
      legacy.rating += 1
      legacy.save
      pub_date = Date.new(2012, 2, 1)
      @l1.publish(pub_date)
      expect(@l1.publications.size).to eq(5)
      p = @l1.publications[4]
      expect(p.total).to eq(subs1)
      expect(p.creates).to eq(0)
      expect(p.remains).to eq(subs1 - 1)
      expect(p.updates).to eq(1)
      expect(p.deletes).to eq(0)
      expect(IcuRating.where("rating != original_rating").count).to eq(1)
      rating = IcuRating.find_by_list_and_icu_id(@l1.date, 1350)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(@legacy[1350].rating)
      expect(rating.full).to eq(@legacy[1350].full)
      expect(rating.original_rating).to eq(@legacy[1350].rating - 1)
      expect(rating.original_full).to eq(@legacy[1350].full)

      # Publish the second list which includes the second tournament.
      pub_date = Date.new(2012, 5, 16)
      pay_date = Date.new(2012, 6, 1)
      @l2.publish(pub_date)
      subs2 = @subs.values.find_all{ |s| s.category == "lifetime" || (s.season == "2011-12" && (!s.pay_date || s.pay_date < pay_date)) }.count
      expect(IcuRating.count).to eq(subs1 + subs2)
      expect(@l2.publications.size).to eq(1)
      p = @l2.publications[0]
      expect(p.total).to eq(subs2)
      expect(p.creates).to eq(subs2)
      expect(p.remains).to eq(0)
      expect(p.updates).to eq(0)
      expect(p.deletes).to eq(0)

      # Player who played in tournament 2 and subscribed in time.
      player = @t3.players.find_by_icu_id(159)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 159)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(player.new_rating)
      expect(rating.full).to eq(player.new_full)
      expect(rating.original_rating).to eq(player.new_rating)
      expect(rating.original_full).to eq(player.new_full)

      # Another player who played in tournament 2 and subscribed in time.
      player = @t3.players.find_by_icu_id(6897)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 6897)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(player.new_rating)
      expect(rating.full).to eq(player.new_full)
      expect(rating.original_rating).to eq(player.new_rating)
      expect(rating.original_full).to eq(player.new_full)

      # Player who didn't play in either tournament but has a subscription.
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 1350)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(@legacy[1350].rating)
      expect(rating.full).to eq(@legacy[1350].full)

      # Simulate adding and rating a new tournament.
      @t2 = test_tournament("intermediate_2012.tab", @u.id)
      @t2.move_stage("ready", @u)
      @t2.move_stage("queued", @u)
      @t3.reload
      expect(@t3.rorder).to be > @t2.rorder

      # Since this new tournament comes before @t3, we have to rerate both.
      @t2.rate!
      @t3.rate!

      # Now republish the list but after the publication month has expired (so original ratings are not altered).
      pub_date = Date.new(2012, 6, 1)
      @l2.publish(pub_date)
      expect(@l2.publications.size).to eq(2)
      p = @l2.publications[1]
      expect(p.total).to eq(subs2)
      expect(p.creates).to eq(0)
      expect(p.remains).to eq(subs2 - 2)
      expect(p.updates).to eq(2)
      expect(p.deletes).to eq(0)

      # Player whose only games are in @t2.
      player = @t2.players.find_by_icu_id(1350)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 1350)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(player.new_rating)
      expect(rating.full).to eq(player.new_full)
      expect(rating.original_rating).to_not eq(player.new_rating)
      expect(rating.original_rating).to eq(@legacy[1350].rating)
      expect(rating.original_full).to eq(@legacy[1350].full)

      # Player whose last games are in @t3.
      player = @t3.players.find_by_icu_id(159)
      expect(player).to_not be_nil
      rating = IcuRating.find_by_list_and_icu_id(@l2.date, 159)
      expect(rating).to_not be_nil
      expect(rating.rating).to eq(player.new_rating)
      expect(rating.full).to eq(player.new_full)
      expect(rating.original_rating).to_not eq(player.new_rating)
    end
  end
end
