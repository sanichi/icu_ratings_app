class AddNewsItemPublished < ActiveRecord::Migration
  def change
    add_column :news_items, :published, :boolean, default: false
    add_index  :news_items, :published
  end
end
