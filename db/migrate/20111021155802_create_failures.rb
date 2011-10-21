class CreateFailures < ActiveRecord::Migration
  def self.up
    create_table :failures do |t|
      t.string   :name
      t.text     :details
      t.datetime :created_at
    end
  end

  def self.down
    drop_table :failures
  end
end
