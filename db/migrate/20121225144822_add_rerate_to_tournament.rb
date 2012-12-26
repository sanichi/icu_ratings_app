class AddRerateToTournament < ActiveRecord::Migration
  def change
    add_column :tournaments, :rerate, :boolean, default: false
  end
end
