class AddNewsItemVisible < ActiveRecord::Migration
  def self.up
    add_column :news_items, :published, :boolean, default: false
    add_index  :news_items, :published
  end

  def self.down
    remove_index  :news_items, :published
    remove_column :news_items, :published
  end
end
