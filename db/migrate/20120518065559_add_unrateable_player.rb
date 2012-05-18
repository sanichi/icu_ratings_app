class AddUnrateablePlayer < ActiveRecord::Migration
  def change
    add_column :players, :unrateable, :boolean, default: false
  end
end
