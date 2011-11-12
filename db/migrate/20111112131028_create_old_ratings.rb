class CreateOldRatings < ActiveRecord::Migration
  def up
    create_table :old_ratings do |t|
      # Warning: column order should match CSV import file (see below).
      t.integer  :icu_id
      t.integer  :rating, :games, limit: 2
      t.boolean  :full, default: false
    end

    # This is fast, despite the large amount of data, but it needs the column order to match and the DB user to have FILE privilege.
    execute "load data infile '#{Rails.root}/db/data/old_ratings.csv' into table old_ratings fields terminated by ','"

    add_index :old_ratings, :icu_id, unique: true
  end

  def down
    drop_table :old_ratings
  end
end
