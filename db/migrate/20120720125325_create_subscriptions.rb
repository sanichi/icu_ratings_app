class CreateSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions do |t|
      t.integer  :icu_id
      t.string   :season, limit: 7
      t.string   :category, limit: 8
      t.date     :pay_date

      t.timestamps
    end

    add_index :subscriptions, :icu_id
    add_index :subscriptions, :season
    add_index :subscriptions, :category
  end
end
