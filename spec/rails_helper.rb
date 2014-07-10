# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'factory_girl_rails'
require 'icu/util/hacks'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
# Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

# Checks for pending migrations before tests are run.
# ActiveRecord::Migration.maintain_test_schema!

# Permit Capybara to recognize ".tab" as a text/plain when file is uploaded.
ICU::Util::Hacks.fix_mime_types

# Be patient with Ajax wait times.
Capybara.configure do |config|
  config.default_wait_time = 15
end

# Don't in general allow pulling member data from www during testing (unless explicitly reset).
User.pulls_disabled = true

RSpec.configure do |config|
  # Shorthand FG syntax.
  # config.include FactoryGirl::Syntax::Methods

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

  # Deduce from location what spec types are (for example, which ones need capybara).
  config.infer_spec_type_from_file_location!
end

# Return a saved Tournament derived from one of the test files.
def test_tournament(file, user_id, arg={})
  opt = Hash.new
  case file
  when "bunratty_masters_2011.tab", "kilkenny_masters_2011.tab"
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
  tournament.upload = FactoryGirl.create(:upload, name: file, user_id: user_id, tournament_id: tournament.id)
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
  user = FactoryGirl.create(:user, role: user.to_s) unless user.instance_of?(User)
  visit "/log_in"
  page.fill_in "Email", with: user.email
  page.fill_in "Password", with: user.password
  click_button "Log in"
  user
end

# Load players in the given tournament(s) only and return hash from ICU ID to record.
def load_icu_players_for(tournaments)
  @tournaments_cache = YAML.load(File.read(File.expand_path('../factories/tournaments.yml', __FILE__)))
  tournaments = [tournaments] unless tournaments.is_a?(Array)
  tournaments.inject([]) do |a, t|
    name = t.sub(/\.[a-z]+$/, "")
    @tournaments_cache[name] ? a.concat(@tournaments_cache[name]) : a
  end.uniq.inject({}) do |h, id|
    h[id] = load_icu_player(id)
    h
  end
end

# Load all players in all tournaments and return hash from ICU ID to record.
def load_icu_players
  @icu_players_cache ||= YAML.load(File.read(File.expand_path('../factories/icu_players.yml', __FILE__)))
  @icu_players_cache.inject({}) do |h, (id, data)|
    h[id] = FactoryGirl.create(:icu_player, data.merge(id: id))
    h
  end
end

# Load a single ICU player given by ID.
def load_icu_player(id)
  @icu_players_cache ||= YAML.load(File.read(File.expand_path('../factories/icu_players.yml', __FILE__)))
  @icu_players_cache[id] ? FactoryGirl.create(:icu_player, @icu_players_cache[id].merge(id: id)) : nil
end

# Load all FIDE players and return hash from FIDE ID to record.
def load_fide_players
  @fide_players_cache ||= YAML.load(File.read(File.expand_path('../factories/fide_players.yml', __FILE__)))
  @fide_players_cache.inject({}) do |h, (id, data)|
    h[id] = FactoryGirl.create(:fide_player_with_icu_id, data.merge(id: id))
    h
  end
end

# Load all old ratings and return hash from ICU ID to record.
def load_old_ratings
  return @old_ratings_cache if @old_ratings_cache
  hash = YAML.load(File.read(File.expand_path('../factories/old_ratings.yml', __FILE__)))
  @old_ratings_cache = hash.keys.inject({}) do |memo, icu_id|
    data = hash[icu_id]
    memo[icu_id] = FactoryGirl.create(:old_rating, icu_id: icu_id, rating: data[0], games: data[1], full: data[2])
    memo
  end
end

# Load all subscriptions and return a hash from ICU ID to record.
def load_subscriptions
  return @subscriptions_cache if @subscriptions_cache
  hash = YAML.load(File.read(File.expand_path('../factories/subscriptions.yml', __FILE__)))
  @subscriptions_cache = hash.keys.inject({}) do |memo, icu_id|
    data = hash[icu_id]
    memo[icu_id] = FactoryGirl.create(:subscription, icu_id: icu_id, category: data[0], season: data[1], pay_date: data[2])
    memo
  end
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
