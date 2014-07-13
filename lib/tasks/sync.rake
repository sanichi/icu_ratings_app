# Note: to invoke optional command line arguments, use square brackets.
# For example: rake sync:fide_players[f].

namespace :sync do
  desc "Synchronize ratings_production/icu_players with www_production/players (schedule daily)"
  task players: :environment do
    ICU::Database::Pull::Player.new.sync
  end

  desc "Synchronize ratings_production/users with www_production/users (schedule daily, after players sync)"
  task users: :environment do
    ICU::Database::Pull::User.new.sync
  end

  desc "Synchronize ratings_production/fees with www_production/items (schedule weekly, for foreign rating fees)"
  task fees: :environment do
    ICU::Database::Pull::Item.new.sync
  end

  desc "Synchronize ratings_production/subscriptions with www_production/items (schedule at least weekly, but run manually before producing a rating list)"
  task :subs, [:season] => :environment do |t, args|
    ICU::Database::Pull::Subs.new.sync(args[:season])
  end

  desc "Synchronize Irish FIDE players with the full download file from fide.com (use [F] to force, schedule weekly)"
  task :irish_fide_players, [:force] => :environment do |t, args|
    args.with_defaults(force: "No")
    FIDE::Download::Irish.new.sync_fide_players(args[:force].match(/^(Y(es)?|F(orce)?)$/i))
  end

  desc "Synchronize Non-Irish FIDE players with the latest download file from fide.com (use [F] to force, schedule weekly)"
  task :other_fide_players, [:force] => :environment do |t, args|
    args.with_defaults(force: "No")
    FIDE::Download::Other.new.sync_fide_players(args[:force].match(/^(Y(es)?|F(orce)?)$/i))
  end

  desc "Synchronize everything in the correct order"
  task all: [:players, :users, :icu_items, :irish_fide_players, :other_fide_players]
end
