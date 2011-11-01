class CreateTournaments < ActiveRecord::Migration
  def change
    create_table :tournaments do |t|
      t.string   :name, :city, :site, :arbiter, :deputy, :tie_breaks, :time_control
      t.date     :start, :finish
      t.string   :fed, limit: 3
      t.integer  :rounds, limit: 1
      t.integer  :user_id

      t.string   :original_name, :original_tie_breaks
      t.date     :original_start, :original_finish

      t.timestamps
    end

    add_index :tournaments, :user_id
  end
end
