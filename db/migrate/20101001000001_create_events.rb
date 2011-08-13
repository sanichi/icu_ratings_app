class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.string   :name
      t.integer  :time, :limit => 2
      t.text     :report
      t.boolean  :success
      t.datetime :created_at
    end
  end

  def self.down
    drop_table :events
  end
end
