set :output, "log/cron.log"

every 1.day, at: "3am" do
  rake "sync:icu_players"
end

every 1.day, at: "4am" do
  rake "sync:icu_users"
end

every :sunday, at: "5am" do
  rake "sync:irish_fide_players"
end

every :sunday, at: "6am" do
  rake "sync:other_fide_players"
end
