class AddTournamentStatusColumn < ActiveRecord::Migration
  def self.up
    add_column :tournaments, :status, :string, default: "ok"
    add_column :tournaments, :stage, :string, limit: 20, default: "unrated"
    add_index  :tournaments, :stage
  end

  def self.down
    remove_index  :tournaments, :stage
    remove_column :tournaments, :stage
    remove_column :tournaments, :status
  end
end
