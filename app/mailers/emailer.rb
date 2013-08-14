class Emailer < ActionMailer::Base
  def notify_tournament_uploaded(tournament)
    @tournament = tournament
    mail(to: "ratings@icu.ie", subject: "New Tournament Uploaded")
  end
end
