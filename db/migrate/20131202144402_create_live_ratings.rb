class CreateLiveRatings < ActiveRecord::Migration
  def up
    create_table :live_ratings do |t|
      t.integer  :icu_id
      t.integer  :rating, limit: 2
      t.integer  :games, limit: 2
      t.boolean  :full, default: false
    end

    add_index :live_ratings, :icu_id, unique: true
  end

  def down
    drop_table :live_ratings
  end
end
