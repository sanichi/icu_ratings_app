class UpdateRatingList < ActiveRecord::Migration
  def up
    rename_column :rating_lists, :cut_off, :tournament_cut_off
    add_column :rating_lists, :payment_cut_off, :date

    RatingList.all.each { |p| p.update_column(:payment_cut_off, p.date.end_of_month) }
  end

  def down
    rename_column :rating_lists, :tournament_cut_off, :cut_off
    remove_column :rating_lists, :payment_cut_off
  end
end
