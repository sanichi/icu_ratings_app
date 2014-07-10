source "http://rubygems.org"

gem "rails", "4.0.2"
gem "mysql2"
gem "haml-rails"
gem "sass"
gem "icu_tournament"
gem "icu_ratings"
gem "icu_name"
gem "validates_timeliness", github: "razum2um/validates_timeliness", ref: "b195081f6aeead619430ad38b0f0dfe4d4981252" # See https://github.com/adzap/validates_timeliness/pull/114.
#gem "validates_timeliness", "~> 3.0"
gem "whenever", :require => false
gem "redcarpet"
gem "cancan", "~> 1.6"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "nokogiri"
gem "rack-mini-profiler"
gem "sass-rails", "~> 4.0.0"
gem "coffee-rails", "~> 4.0.0"
gem "therubyracer", :require => "v8"
gem "uglifier"

group :development do
  gem "capistrano", "~> 2.15"
  gem "capistrano-maintenance", "~> 0.0.4"
  gem "quiet_assets"
  gem "wirble"
end

group :test, :development do
  gem "rspec-rails", "2.99"
  gem "capybara"
  gem "selenium-webdriver"
  gem "launchy"
  gem "factory_girl_rails"
  gem "faker"
  gem "database_cleaner"
end
