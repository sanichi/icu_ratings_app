set :output, "log/cron.log"

every 1.minute do
  command "cd #{path}; F=tmp/#{@environment}_rating_run; if [ -f $F ]; then mv $F ${F}_; RAILS_ENV=#{@environment} bin/rake rating:run --silent; fi"
end

every :day, at: "3:00am" do
  rake "sync:icu_players"
end

every :day, at: "3:30am" do
  rake "sync:icu_users"
end

every :day, at: "4:00am" do
  rake "sync:icu_items"
end

every :day, at: "4:30am" do
  rake "sync:icu_subs"
end

every :day, at: "5:00am" do
  rake "export:ratings"
end

every :sunday, at: "5:30am" do
  rake "sync:irish_fide_players"
end

every :sunday, at: "6:0am" do
  rake "sync:other_fide_players"
end
