class AddIterationsToTournament < ActiveRecord::Migration
  def change
    add_column :tournaments, :iterations1, :integer, limit: 2, default: 0
    add_column :tournaments, :iterations2, :integer, limit: 2, default: 0
  end
end
