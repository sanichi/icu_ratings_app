class AddNotesToPublications < ActiveRecord::Migration
  def change
    add_column :publications, :notes, :text
  end
end
