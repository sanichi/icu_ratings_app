# Note: to invoke optional command line arguments, use square brackets.
# For example: rake sync:fide_players[f].

namespace :sync do
  desc "Synchronize IcuPlayers to icu_players in the www.icu.ie database"
  task icu_players: :environment do
    ICU::Database::Player.new.sync
  end

  desc "Synchronize Users to members in the www.icu.ie database"
  task icu_users: :environment do
    ICU::Database::Member.new.sync
  end

  desc "Synchronize FidePlayers and FideRatings to fide_players and fide_ratings in the www.icu.ie database"
  task icu_fide_data: :environment do
    ICU::Database::FIDE.new.sync
  end

  desc "Synchronize Irish FIDE players to the full download file from fide.com (use [F] to force)"
  task :irish_fide_players, [:force] => :environment do |t, args|
    args.with_defaults(force: "No")
    FIDE::Download::Irish.new.sync_fide_players(args[:force].match(/^(Y(es)?|F(orce)?)$/i))
  end

  desc "Synchronize Non-Irish FIDE players to the latest download file from fide.com (use [F] to force)"
  task :other_fide_players, [:force] => :environment do |t, args|
    args.with_defaults(force: "No")
    FIDE::Download::Other.new.sync_fide_players(args[:force].match(/^(Y(es)?|F(orce)?)$/i))
  end
  
  desc "Synchronize everything in the correct order"
  task all: [:icu_players, :icu_users, :irish_fide_players, :other_fide_players]
end
