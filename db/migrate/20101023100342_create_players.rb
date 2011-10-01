class CreatePlayers < ActiveRecord::Migration
  def self.up
    create_table :players do |t|
      t.string   :first_name, :last_name
      t.string   :fed, :title, limit: 3
      t.string   :gender, limit: 1
      t.integer  :icu_id, :fide_id
      t.integer  :icu_rating, :fide_rating, limit: 2
      t.date     :dob
      t.string   :status, :category
      t.integer  :rank, limit: 2
      t.integer  :num, :tournament_id

      t.string   :original_name
      t.string   :original_fed, :original_title, limit: 3
      t.string   :original_gender, limit: 1
      t.integer  :original_icu_id, :original_fide_id
      t.integer  :original_icu_rating, :original_fide_rating, limit: 2
      t.date     :original_dob

      t.timestamps
    end
    
    add_index :players, :tournament_id
    add_index :players, :icu_id
    add_index :players, :fide_id
  end

  def self.down
    drop_table :players
  end
end
