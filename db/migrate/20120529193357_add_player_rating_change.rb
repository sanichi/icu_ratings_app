class AddPlayerRatingChange < ActiveRecord::Migration
  def up
    add_column   :players, :rating_change, :integer, limit: 2, default: 0
    add_index    :players, :rating_change
    Player.all.each do |p|
      p.update_column(:rating_change, p.new_rating - p.old_rating) if p.new_rating && p.old_rating
    end
  end

  def down
    remove_index  :players, :rating_change
    remove_column :players, :rating_change
  end
end
