source "http://rubygems.org"

gem "rails", "3.1.2"
gem "mysql2"
gem "haml"
gem "sass"
gem "icu_tournament"
gem "icu_name"
gem "validates_timeliness"
gem "whenever", :require => false
gem "redcarpet"
gem "cancan", "~> 1.6"
gem "jquery-rails"
gem "therubyracer", :require => "v8"

group :assets do
  gem "sass-rails", "3.1.5"
  gem "coffee-rails", "3.1.1"
end

group :development do
  gem "capistrano"
  gem "pry"
  gem "hirb"
end

group :test, :darwin do
  gem "rb-fsevent", :require => false
  gem "growl", :require => false
end

group :test, :development do
  gem "rspec-rails"
  gem "capybara"
  gem "launchy"
  gem "factory_girl_rails"
  gem "faker"
  gem "guard-rspec"
  gem "database_cleaner"
end
