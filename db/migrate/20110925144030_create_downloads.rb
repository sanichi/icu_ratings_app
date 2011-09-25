class CreateDownloads < ActiveRecord::Migration
  def self.up
    create_table :downloads do |t|
      t.string :comment
      t.string :file_name
      t.string :content_type
      t.binary :data, :limit => 1.megabyte

      t.timestamps
    end
  end

  def self.down
    drop_table :downloads
  end
end
