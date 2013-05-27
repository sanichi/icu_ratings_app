source "http://rubygems.org"

gem "rails", "3.2.13"
gem "mysql2"
gem "haml-rails"
gem "sass"
gem "icu_tournament"
gem "icu_ratings"
gem "icu_name"
gem "validates_timeliness"
gem "whenever", :require => false
gem "redcarpet"
gem "cancan", "~> 1.6"
gem "jquery-rails"
gem "nokogiri"
gem "rack-mini-profiler"

group :assets do
  gem "sass-rails", ">= 3.2.3"
  gem "coffee-rails", ">= 3.2.1"
  gem "therubyracer", :require => "v8"
end

group :development do
  gem "capistrano"
  gem "capistrano-maintenance"
  gem "quiet_assets"
  gem "better_errors"      # see ...
  gem "binding_of_caller"  # railscasts ...
  gem "meta_request"       # 402
end

group :test, :development do
  gem "rspec-rails"
  gem "capybara"
  gem "selenium-webdriver"
  gem "launchy"
  gem "factory_girl_rails"
  gem "faker"
  gem "database_cleaner"
end

gem "newrelic_rpm"
