class Emailer < ActionMailer::Base
  def notify_tournament_uploaded(tournament)
    @name = tournament.name
    @time = tournament.created_at.to_s(:db)
    @user = tournament.user.name(false)
    @link = admin_tournament_url(tournament.id, host: "ratings.icu.ie")
    mail(to: "ratings@icu.ie", subject: "New Tournament Uploaded")
  end
end
