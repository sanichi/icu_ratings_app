set :output, "log/cron.log"
set :job_template, nil # set explicit PATH in crontab instead

every 1.minute do
  command "cd #{path}; F=tmp/#{@environment}_rating_run; if [ -f $F ]; then mv $F ${F}_; RAILS_ENV=#{@environment} bin/rake rating:run --silent; fi"
end

every :day, at: "3:00am" do
  rake "sync:players"
end

every :day, at: "3:30am" do
  rake "sync:users"
end

# every :day, at: "4:00am" do
#   rake "sync:fees"
# end

every :day, at: "4:30am" do
  rake "sync:subs"
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
