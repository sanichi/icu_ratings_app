class AddIdentifierToArticles < ActiveRecord::Migration
  def change
    add_column :articles, :identity, :string, length: 32
  end
end
