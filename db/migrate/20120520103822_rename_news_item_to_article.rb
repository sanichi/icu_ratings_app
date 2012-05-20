class RenameNewsItemToArticle < ActiveRecord::Migration
  def up
    remove_index :news_items, :user_id
    remove_index :news_items, :published
    rename_table :news_items, :articles
    add_index    :articles, :user_id
    add_index    :articles, :published
  end

  def down
    remove_index :articles, :user_id
    remove_index :articles, :published
    rename_table :articles, :news_items
    add_index    :news_items, :user_id
    add_index    :news_items, :published
  end
end
