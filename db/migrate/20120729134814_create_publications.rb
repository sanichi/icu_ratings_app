class CreatePublications < ActiveRecord::Migration
  def up
    create_table :publications do |t|
      t.integer  :rating_list_id, :last_tournament_id
      t.text     :report
      t.datetime :created_at
      t.integer  :total, :creates, :remains, :updates, :deletes, limit: 3
    end
    add_index :publications, :rating_list_id
    change_table :icu_ratings do |t|
      t.integer  :original_rating, limit: 2
      t.boolean  :original_full
    end
    execute "UPDATE icu_ratings SET original_rating = rating, original_full = full"
  end

  def down
    drop_table :publications
    change_table :icu_ratings do |t|
      t.remove :original_rating
      t.remove :original_full
    end
  end
end
