class AddTournamentStaging < ActiveRecord::Migration
  def up
    change_table :tournaments do |t|
      t.change_default :stage, "initial"
      t.integer        :rorder
      t.index          :rorder, unique: true
    end
    execute "UPDATE tournaments SET stage = 'initial' WHERE stage = 'scratch'"
    execute "UPDATE tournaments SET stage = 'ready'   WHERE stage = 'unrated'"
  end

  def down
    change_table :tournaments do |t|
      t.remove_index   :rorder
      t.remove         :rorder
      t.change_default :stage, "scratch"
    end
    execute "UPDATE tournaments SET stage = 'scratch' WHERE stage = 'initial'"
    execute "UPDATE tournaments SET stage = 'unrated' WHERE stage IS NOT NULL AND stage != 'scratch'"
  end
end
