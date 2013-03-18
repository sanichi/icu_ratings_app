class AddOldRatingsFromArchive < ActiveRecord::Migration
  # You can add new records to this migration and rerun it:
  # RAILS_ENV=production bin/rake db:migrate:redo VERSION=20120604061351
  RECORDS =
  [
    {icu_id:   357, rating: 1631, games:  3, full: true},  # resurrected from former players
    {icu_id:   552, rating: 1692, games: 11, full: true},
    {icu_id:  1074, rating: 1821, games:  7, full: true},
    {icu_id:  1211, rating: 1727, games: 11, full: true},  # resurrected from former players
    {icu_id:  1305, rating: 1190, games: 30, full: true},
    {icu_id:  2059, rating: 1071, games: 20, full: true},  # old Fred Harte data, number of games guessed
    {icu_id:  2404, rating: 1210, games:  6, full: true},
    {icu_id:  3758, rating: 1507, games: 12, full: true},
    {icu_id:  4126, rating:  938, games: 35, full: true},
    {icu_id: 13382, rating: 1196, games: 80, full: true},
    {icu_id: 13386, rating: 1514, games: 20, full: true},  # old Fred Harte data, number of games guessed
    {icu_id: 13442, rating: 1339, games: 20, full: true},  # old Fred Harte data, number of games guessed
    {icu_id: 13448, rating: 1401, games: 20, full: true},  # old Fred Harte data, number of games guessed
    {icu_id: 13450, rating: 1444, games: 20, full: true},  # old Fred Harte data, number of games guessed
  ]

  def up
    RECORDS.each { |hash| OldRating.where(icu_id: hash[:icu_id]).first_or_create(hash, without_protection: true) }
  end

  def down
    RECORDS.each{ |hash| OldRating.find_by_icu_id(hash[:icu_id]).try(:destroy) }
  end
end
