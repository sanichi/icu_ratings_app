class AddOldRatingsFromArchive < ActiveRecord::Migration
  def up
    OldRating.create!(icu_id: 1305, rating: 1190, games: 30, full: true)
    OldRating.create!(icu_id: 2404, rating: 1210, games:  6, full: true)
    OldRating.create!(icu_id: 3758, rating: 1507, games: 12, full: true)    
  end

  def down
    [1305, 2404, 3758].each { |icu_id| OldRating.find_by_icu_id(icu_id).destroy }
  end
end
