class RenameFidePlayerId < ActiveRecord::Migration
  def up
    remove_index :fide_ratings, column: :fide_player_id
    rename_column :fide_ratings, :fide_player_id, :fide_id
    add_index :fide_ratings, :fide_id
  end

  def down
    remove_index :fide_ratings, column: :fide_id
    rename_column :fide_ratings, :fide_id, :fide_player_id
    add_index :fide_ratings, :fide_player_id
  end
end
