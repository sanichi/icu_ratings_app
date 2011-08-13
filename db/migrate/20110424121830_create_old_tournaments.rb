class CreateOldTournaments < ActiveRecord::Migration
  def self.up
    # WARNING: column order should match CSV import file.
    create_table :old_tournaments do |t|
      t.string   :name
      t.date     :date
      t.integer  :player_count, :limit => 2
    end

    # This is fast but it needs the column order to match and the DB user to have FILE privilege.
    execute "load data local infile '#{Rails.root}/db/data/old_tournaments.csv' into table old_tournaments fields terminated by ','"
  end

  def self.down
    drop_table :old_tournaments
  end
end
