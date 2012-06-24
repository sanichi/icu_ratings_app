class CreateFees < ActiveRecord::Migration
  def change
    create_table :fees do |t|
      t.string   :description
      t.string   :status, limit: 25
      t.string   :category, limit: 3
      t.date     :date
      t.integer  :icu_id
      t.boolean  :used, default: false
      t.timestamps
    end
  end
end
