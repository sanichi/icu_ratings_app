class AddNoteToTournament < ActiveRecord::Migration
  def change
    add_column :tournaments, :notes, :text
  end
end
