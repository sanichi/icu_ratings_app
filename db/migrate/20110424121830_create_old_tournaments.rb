class CreateOldTournaments < ActiveRecord::Migration
  def up
    create_table :old_tournaments do |t|
      # Warning: column order should match CSV import file (see below).
      t.string   :name
      t.date     :date
      t.integer  :player_count, limit: 2
    end

    # This is fast, despite the moderate amount of data, but it needs the column order to match and the DB user to have FILE privilege.
    execute "load data infile '#{Rails.root}/db/data/old_tournaments.csv' into table old_tournaments fields terminated by ','"
  end

  def down
    drop_table :old_tournaments
  end
end
