source "http://rubygems.org"

gem "rails", "4.1.5"
gem "mysql2"
gem "icu_tournament"
gem "icu_ratings"
gem "icu_name"
gem "validates_timeliness", github: "razum2um/validates_timeliness", ref: "b195081f6aeead619430ad38b0f0dfe4d4981252" # See https://github.com/adzap/validates_timeliness/pull/114.
#gem "validates_timeliness", "~> 3.0"
gem "whenever", :require => false
gem "redcarpet"
gem "nokogiri"
gem "cancan", "~> 1.6"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "rack-mini-profiler"
gem "haml-rails"
gem "sass-rails", "~> 4.0.3"
gem "coffee-rails", "~> 4.0.0"
gem "therubyracer", platforms: :ruby
gem "uglifier"

group :development do
  gem "capistrano-rails"
  gem "wirble"
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
