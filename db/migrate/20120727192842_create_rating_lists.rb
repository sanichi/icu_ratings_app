class CreateRatingLists < ActiveRecord::Migration
  def up
    create_table :rating_lists do |t|
      t.date :date

      t.timestamps
    end
    change_table :icu_ratings do |t|
      t.integer  :original_rating, limit: 2
      t.boolean  :original_full, default: false
    end
    add_index :rating_lists, :date
  end

  def down
    drop_table :rating_lists
    change_table :icu_ratings do |t|
      t.remove :original_rating
      t.remove :original_full
    end
  end
end

