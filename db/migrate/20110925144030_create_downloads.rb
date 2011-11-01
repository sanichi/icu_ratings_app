class CreateDownloads < ActiveRecord::Migration
  def change
    create_table :downloads do |t|
      t.string :comment
      t.string :file_name
      t.string :content_type
      t.binary :data, limit: 1.megabyte

      t.timestamps
    end
  end
end
