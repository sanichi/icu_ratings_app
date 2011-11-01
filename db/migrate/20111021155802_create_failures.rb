class CreateFailures < ActiveRecord::Migration
  def change
    create_table :failures do |t|
      t.string   :name
      t.text     :details
      t.datetime :created_at
    end
  end
end
