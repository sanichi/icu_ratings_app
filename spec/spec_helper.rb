# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
end

# Return exactly the same type of object used for file uploads.
def test_upload(name, arg={})
  path = test_file_path(name)
  if arg[:type].blank?
    arg[:type] = case name
      when /\.zip$/ then "application/octet-stream"
      else "text/plain"
    end
  end
  arg[:param] = name if arg[:param].blank?
  tempfile = Tempfile.new('foo')
  FileUtils.cp(path, tempfile.path)
  hash =
  {
    :filename => name,
    :type     => arg[:type],
    :tempfile => tempfile,
    :head     => "Content-Disposition: form-data; name=\"#{arg[:param]}\"; filename=\"#{name}\"\r\nContent-Type: #{arg[:type]}\r\n"
  }
  ActionDispatch::Http::UploadedFile.new(hash)
end

# Return a saved Tournament derived from one of the test files.
def test_tournament(name, arg={})
  path = test_file_path(name)
  opt = Hash.new
  case name
  when /\.(zip|txt)$/
    parser = "ICU::Tournament::#{$1 == 'zip' ? 'SwissPerfect' : 'SPExport'}".constantize.new
    opt[:start] = arg[:start] || "2011-03-06"
    opt[:name] = arg[:name] if arg.has_key?(:name)
  when /\.tab$/
    parser = ICU::Tournament::Krause.new
    opt[:fide] = arg[:fide] if arg.has_key?(:fide)
  when /\.csv$/
    parser = ICU::Tournament::ForeignCSV.new
  end
  icut = parser.parse_file!(path, opt)
  tournament = Tournament.build_from_icut(icut)
  tournament.user_id = arg[:user_id] if arg[:user_id]
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
def login_user(role)
  user = Factory(:user, :role => role)
  visit "/log_in"
  page.fill_in "Email", :with => user.email
  page.fill_in "Password", :with => user.password
  click_button "Log in"
  user
end
