class RenameFideRatingPeriod < ActiveRecord::Migration
  def up
    rename_column :fide_ratings, :period, :list
    add_index     :fide_ratings, :list
  end
  
  def down
    remove_index  :fide_ratings, :list
    rename_column :fide_ratings, :list, :period
  end
end
