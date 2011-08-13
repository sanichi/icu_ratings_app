source "http://rubygems.org"

gem "rails", "3.0.9"
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

group :development do
  gem "hirb"
end

group :test, :development do
  gem "rspec-rails"
  gem "capybara"
  gem "launchy"
  gem "factory_girl_rails"
  gem "faker"
  gem "guard-rspec"
  if RUBY_PLATFORM =~ /darwin/i
    gem "rb-fsevent", :require => false
    gem "growl", :require => false
  end
end

# Deploy with Capistrano.
# gem 'capistrano'
