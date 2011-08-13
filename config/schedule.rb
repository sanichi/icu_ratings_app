set :output, "log/cron.log"

every 1.day, :at => '8pm' do
  rake "sync:icu_players"
end

every 1.day, :at => '9pm' do
  rake "sync:icu_users"
end

every :thursday, :at => '10pm' do
  rake "sync:irish_fide_players"
end

every :thursday, :at => '11pm' do
  rake "sync:other_fide_players"
end
