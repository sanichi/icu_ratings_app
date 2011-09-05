source "http://rubygems.org"

gem "rails", "3.0.10"
gem "mysql2", "0.2.6"

gem "haml"
gem "sass"
gem "icu_tournament"
gem "icu_name"
gem "validates_timeliness"
gem "whenever", :require => false
gem "escape_utils"
gem "redcarpet"
gem "cancan", "~> 1.6"
gem "newrelic_rpm"

group :development do
  gem "hirb"
  gem "capistrano"
  gem "pry"
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
end
