class CreateFidePlayerFiles < ActiveRecord::Migration
  def change
    create_table :fide_player_files do |t|
      t.text     :description
      t.integer  :players_in_file,  default: 0, limit: 2
      t.boolean  :new_fide_records, default: 0, limit: 2
      t.boolean  :new_icu_mappings, default: 0, limit: 2
      t.integer  :user_id
      t.datetime :created_at
    end
  end
end
