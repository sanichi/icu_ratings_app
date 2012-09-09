class AddFideIdToTournament < ActiveRecord::Migration
  def change
    add_column :tournaments, :fide_id, :integer
  end
end
