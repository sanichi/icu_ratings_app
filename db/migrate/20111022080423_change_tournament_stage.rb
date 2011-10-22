class ChangeTournamentStage < ActiveRecord::Migration
  def self.up
    change_column :tournaments, :stage, :string, limit: 20, default: "scratch"
  end

  def self.down
    change_column :tournaments, :stage, :string, limit: 20, default: "unrated"
  end
end
