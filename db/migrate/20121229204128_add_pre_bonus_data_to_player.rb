class AddPreBonusDataToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :pre_bonus_rating, :integer, limit: 2
    add_column :players, :pre_bonus_performance, :integer, limit: 2
  end
end
