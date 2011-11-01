class CreateFidePlayers < ActiveRecord::Migration
  def change
    create_table :fide_players do |t|
      # Warning: column order is important because of the way syncing is implemented (lib/fide/download.rb).
      t.string   :last_name, :first_name
      t.string   :fed, :title, limit: 3
      t.string   :gender, limit: 1
      t.integer  :born, :rating, limit: 2
      t.integer  :icu_id

      t.timestamps
    end

    # Warning: too many indexes here will slow down syncing (lib/fide/download.rb).
    add_index :fide_players, [:last_name, :first_name]
    add_index :fide_players, :icu_id
  end
end
