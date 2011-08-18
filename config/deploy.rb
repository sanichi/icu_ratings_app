set :whenever_command, "bin/whenever"
require "bundler/capistrano"
require "whenever/capistrano"

set :application, "ratings.icu.ie"
role :app, application
role :web, application
role :db,  application, :primary => true

set :user, "mjo"
set :deploy_to, "/var/apps/ratings"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, :git
set :repository, "git://github.com/sanichi/icu_ratings_app.git"
set :branch, "master"

namespace :deploy do
  desc "Tell Passenger to restart."
  task :restart, :roles => :web do
    run "touch #{deploy_to}/current/tmp/restart.txt"
  end

  desc "Do nothing on startup so we don't get a script/spin error."
  task :start do
    puts "You may need to restart Apache"
  end

  desc "Symlink extra configs and folders."
  task :symlink_extras do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/app_config.yml #{release_path}/config/app_config.yml"
    run "ln -nfs #{shared_path}/config/newrelic.yml #{release_path}/config/newrelic.yml"
  end

  desc "Setup shared directory."
  task :setup_shared do
    run "mkdir #{shared_path}/config"
    put File.read("config/examples/database.yml"), "#{shared_path}/config/database.yml"
    put File.read("config/examples/app_config.yml"), "#{shared_path}/config/app_config.yml"
    puts "Now edit the config files in #{shared_path}."
  end

  desc "Make sure there is something to deploy."
  task :check_revision, :roles => :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
end

before "deploy", "deploy:check_revision"
after "deploy", "deploy:cleanup"
after "deploy:setup", "deploy:setup_shared"
after "deploy:update_code", "deploy:symlink_extras"
