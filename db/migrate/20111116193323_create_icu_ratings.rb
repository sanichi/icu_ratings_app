class CreateIcuRatings < ActiveRecord::Migration
  def up
    create_table :icu_ratings do |t|
      # Warning: column order should match CSV import file.
      t.integer  :list, limit: 3
      t.integer  :icu_id
      t.integer  :rating, limit: 2
      t.boolean  :full, default: false
    end

    # This is fast but it needs the column order to match and the DB user to have FILE privilege.
    execute "load data infile '#{Rails.root}/db/data/icu_ratings.csv' into table icu_ratings fields terminated by ','"

    add_index :icu_ratings, :icu_id
    add_index :icu_ratings, :list
    add_index :icu_ratings, [:list, :icu_id], unique: true
  end

  def down
    drop_table :icu_ratings
  end
end
