class CreateOldRatingHistories < ActiveRecord::Migration
  def self.up
    # Warning: column order should match CSV import file.
    create_table :old_rating_histories do |t|
      t.integer  :old_tournament_id, :icu_player_id
      t.integer  :old_rating, :new_rating, :performance_rating, :tournament_rating, :limit => 2
      t.integer  :bonus, :limit => 2
      t.integer  :games, :kfactor, :limit => 1
      t.decimal  :actual_score, :precision => 3, :scale => 1
      t.decimal  :expected_score, :precision => 8, :scale => 6
    end

    # This is fast but it needs the column order to match and the DB user to have FILE privilege.
    execute "load data local infile '#{Rails.root}/db/data/old_rating_histories.csv' into table old_rating_histories fields terminated by ','"

    add_index :old_rating_histories, :old_tournament_id
    add_index :old_rating_histories, :icu_player_id
    add_index :old_rating_histories, [:old_tournament_id, :icu_player_id], :unique => true, :name => "by_icu_player_old_tournament"
  end

  def self.down
    drop_table :old_rating_histories
  end
end
