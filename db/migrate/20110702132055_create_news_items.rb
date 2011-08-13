class CreateNewsItems < ActiveRecord::Migration
  def self.up
    create_table :news_items do |t|
      t.string   :headline
      t.text     :story
      t.integer  :user_id

      t.timestamps
    end

    add_index :news_items, :user_id
  end

  def self.down
    drop_table :news_items
  end
end
