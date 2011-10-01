class CreateResults < ActiveRecord::Migration
  def self.up
    create_table :results do |t|
      t.integer  :round, limit: 1
      t.integer  :player_id, :opponent_id
      t.string   :result, :colour, limit: 1
      t.boolean  :rateable

      t.timestamps
    end
    
    add_index :results, :player_id
    add_index :results, :opponent_id
  end

  def self.down
    drop_table :results
  end
end
