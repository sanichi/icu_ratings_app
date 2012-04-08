class AddPlayerStartRating < ActiveRecord::Migration
  def up
    change_table :tournaments do |t|
      t.integer  :reratings, limit: 2, default: 0
      t.integer  :next_tournament_id, :last_tournament_id, :old_last_tournament_id
      t.datetime :first_rated, :last_rated
      t.integer  :last_rated_msec, limit: 2
      t.string   :last_signature, :curr_signature, limit: 32
    end
    change_table :players do |t|
      t.integer :old_rating, :new_rating, :trn_rating, limit: 2
      t.integer :old_games, :new_games, limit: 2
      t.integer :bonus, limit: 2
      t.integer :k_factor, limit: 1
      t.integer :last_player_id
      t.decimal :actual_score, precision: 3, scale: 1
      t.decimal :expected_score, precision: 8, scale: 6
      t.string  :last_signature, :curr_signature
    end
    change_table :results do |t|
      t.decimal :expected_score, :rating_change, precision: 8, scale: 6
    end
    add_index :tournaments, :last_rated
    add_index :tournaments, :last_rated_msec
    add_index :tournaments, :last_tournament_id
    add_index :tournaments, :old_last_tournament_id
    add_index :tournaments, :last_signature
    add_index :tournaments, :curr_signature
    ts = Tournament.where("rorder IS NOT NULL").order(:rorder)
    ts.each_with_index do |t, i|
      t.update_column(:last_tournament_id, i > 0   ? ts[i-1].id : nil)
      t.update_column(:next_tournament_id, ts[i+1] ? ts[i+1].id : nil)
    end
  end

  def down
    remove_index :tournaments, :last_rated
    remove_index :tournaments, :last_rated_msec
    remove_index :tournaments, :last_tournament_id
    remove_index :tournaments, :old_last_tournament_id
    remove_index :tournaments, :last_signature
    remove_index :tournaments, :curr_signature
    change_table :results do |t|
      t.remove :expected_score, :rating_change
    end
    change_table :players do |t|
      t.remove :old_rating, :new_rating, :trn_rating
      t.remove :old_games, :new_games
      t.remove :bonus, :k_factor
      t.remove :actual_score, :expected_score
      t.remove :last_player_id
      t.remove :last_signature, :curr_signature
    end
    change_table :tournaments do |t|
      t.remove :reratings
      t.remove :next_tournament_id, :last_tournament_id, :old_last_tournament_id
      t.remove :first_rated, :last_rated, :last_rated_msec
      t.remove :last_signature, :curr_signature
    end
  end
end
