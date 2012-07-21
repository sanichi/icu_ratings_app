# Note: to invoke optional command line arguments, use square brackets.
# For example: rake sync:fide_players[f].

namespace :sync do
  desc "Synchronize IcuPlayers with icu_players in the www.icu.ie database (schedule daily)"
  task icu_players: :environment do
    ICU::Database::Player.new.sync
  end

  desc "Synchronize Users with members in the www.icu.ie database (schedule daily)"
  task icu_users: :environment do
    ICU::Database::Member.new.sync
  end

  desc "Synchronize Fees with items in the www.icu.ie database (schedule weekly)"
  task icu_items: :environment do
    ICU::Database::Item.new.sync
  end

  desc "Synchronize Subscriptions with the www.icu.ie database (schedule at least weekly, but run manually before producing a rating list)"
  task :icu_subs, [:season] => :environment do |t, args|
    ICU::Database::Subs.new.sync(args[:season])
  end

  desc "Synchronize FidePlayers and FideRatings with fide_players and fide_ratings in the www.icu.ie database (perform once)"
  task icu_fide_data: :environment do
    ICU::Database::FIDE.new.sync
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
  task all: [:icu_players, :icu_users, :icu_items, :irish_fide_players, :other_fide_players]
end
