class CreateIcuPlayers < ActiveRecord::Migration
  def self.up
    create_table :icu_players do |t|
      t.string   :first_name, :last_name, :email, :club, :address, :phone_numbers
      t.string   :fed, :title, limit: 3
      t.string   :gender, limit: 1
      t.text     :note
      t.date     :dob, :joined
      t.boolean  :deceased
      t.integer  :master_id

      t.timestamps
    end
    
    add_index :icu_players, [:last_name, :first_name]
  end

  def self.down
    drop_table :icu_players
  end
end
