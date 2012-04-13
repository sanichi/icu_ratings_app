class AddTournamentLock < ActiveRecord::Migration
  def change
    add_column :tournaments, :locked, :boolean, default: false
  end
end
