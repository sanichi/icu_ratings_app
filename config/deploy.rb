set :application, "icu_ratings_app"

set :repo_url, "git://github.com/sanichi/icu_ratings_app.git"
set :branch, "master"

set :deploy_to, "/var/apps/ratings"

set :linked_files, %w{config/database.yml config/secrets.yml}
set :linked_dirs, %w{log tmp/pids public/system public/webalizer}  # capistrano/rails adds public/assets

set :maintenance_file, "public/system/maintenance.html"

set :log_level, :info

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5
