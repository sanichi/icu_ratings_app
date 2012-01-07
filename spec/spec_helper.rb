# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner'
require 'util/hacks'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

# Permit Capybara to recognize ".tab" as a text/plain when file is uploaded.
Util::Hacks.fix_mime_types

RSpec.configure do |config|
  # Mock framework.
  config.mock_with :rspec

  # To be able to use selenium tests we use database_cleaner with truncation
  # strategy for all tests (slower but more reliable). See Railscasts 257.
  config.use_transactional_fixtures = false
  unless config.use_transactional_fixtures
    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
    end
    config.after(:each) do
      DatabaseCleaner.clean
    end
  end
end

# Return a saved Tournament derived from one of the test files.
def test_tournament(file, user_id, arg={})
  opt = Hash.new
  case file
  when "bunratty_masters_2011.tab"
    opt[:fide] = arg.has_key?(:fide) ? arg[:fide] : true
  when "junior_championships_u19_2010.txt"
    opt[:start] = arg[:start].presence || "2010-04-11"
    opt[:name] = arg[:name].presence || "U-19 All Ireland"
  when "junior_championships_u19_2010.zip"
    opt[:start] = arg[:start].presence || "2010-04-11"
  end
  parser = get_parser(file)
  begin
    icut = parser.parse_file!(test_file_path(file), opt)
  rescue ArgumentError
    icut = parser.parse_file!(test_file_path(file))
  end
  tournament = Tournament.build_from_icut(icut)
  tournament.user_id = user_id
  tournament.save!
  tournament.upload = Factory(:upload, name: file, user_id: user_id, tournament_id: tournament.id)
  tournament.save!
  tournament.renumber_opponents
  tournament
end

# Where are the test files?
def test_file_path(name)
  path = Rails.root + "spec/files/#{name}"
  raise "non-existant sample file (#{name})" unless File.exists?(path)
  path
end

# Create and login a user with a given role.
def login(user)
  if user == "guest"
    visit "/log_out"
    return
  end
  user = Factory(:user, role: user.to_s) unless user.instance_of?(User)
  visit "/log_in"
  page.fill_in "Email", with: user.email
  page.fill_in "Password", with: user.password
  click_button "Log in"
  user
end

def load_icu_players_for(tournaments)
  @tournaments_cache ||= YAML.load(File.read(File.expand_path('../factories/tournaments.yml', __FILE__)))
  tournaments = [tournaments] unless tournaments.is_a?(Array)
  tournaments.inject([]) do |ids, t|
    n = t.sub(/\.[a-z]+$/, "")
    @tournaments_cache[n] ? ids.concat(@tournaments_cache[n]) : ids
  end.uniq.each do |id|
    load_icu_player(id)
  end
end

def load_icu_player(id)
  @icu_players_cache ||= YAML.load(File.read(File.expand_path('../factories/icu_players.yml', __FILE__)))
  Factory(:icu_player, @icu_players_cache[id].merge(id: id)) if @icu_players_cache[id]
end

private

def get_parser(file)
  parser = case file
    when /\.txt$/ then "SPExport"
    when /\.zip$/ then "SwissPerfect"
    when /\.tab$/ then "Krause"
    when /\.csv$/ then "ForeignCSV"
  end
  "ICU::Tournament::#{parser}".constantize.new
end
