class AddOldRatingToLiveRatings < ActiveRecord::Migration
  def change
    add_column :live_ratings, :last_rating, :integer, limit: 2
    add_column :live_ratings, :last_full, :boolean, default: false
  end
end
