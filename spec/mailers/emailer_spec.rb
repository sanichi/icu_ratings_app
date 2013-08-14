require "spec_helper"

describe Emailer do
  context "#notify_tournament_uploaded" do
    before(:each) do
      @u = FactoryGirl.create(:user, role: "reporter")
      @t = test_tournament("bunratty_masters_2011.tab", @u.id)
      @n = ActionMailer::Base.deliveries.size
    end

    it "should send notification to rating officer" do
      email = Emailer.notify_tournament_uploaded(@t).deliver
      expect(ActionMailer::Base.deliveries.size).to eq(@n + 1)
      expect(email.to).to include("ratings@icu.ie")
      expect(email.from).to include("mjo@ratalacha.icu.ie")
      expect(email.subject).to eq("New Tournament Uploaded")
      expect(email.body).to include("Name: #{@t.name}")
      expect(email.body).to include("Date: #{@t.finish.to_s(:db)}")
      expect(email.body).to include("User: #{@u.name(false)}")
      expect(email.body).to include("Time: #{@t.created_at.to_s(:db)}")
      expect(email.body).to include("Link: http://ratings.icu.ie/admin/tournaments/#{@t.id}")
    end
  end
end
