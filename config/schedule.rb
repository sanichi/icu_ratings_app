set :output, "log/cron.log"

every 1.minute do
  command "cd #{path}; F=tmp/#{@environment}_rating_run; if [ -f $F ]; then mv $F ${F}_; RAILS_ENV=#{@environment} bin/rake rating:run --silent; fi"
end

every :day, at: "3am" do
  rake "sync:icu_players"
end

every :day, at: "4am" do
  rake "sync:icu_users"
end

every :day, at: "5am" do
  rake "sync:icu_items"
end

every :sunday, at: "6am" do
  rake "sync:irish_fide_players"
end

every :sunday, at: "7am" do
  rake "sync:other_fide_players"
end
