class CreateRatingLists < ActiveRecord::Migration
  def up
    create_table :rating_lists do |t|
      t.date     :date
      t.datetime :created_at
    end
    add_index :rating_lists, :date
  end

  def down
    drop_table :rating_lists
  end
end

