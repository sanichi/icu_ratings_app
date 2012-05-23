class CreateRatingRun < ActiveRecord::Migration
  def change
    create_table :rating_runs do |t|
      t.integer  :user_id
      t.string   :status
      t.text     :report
      t.integer  :start_tournament_id, :last_tournament_id
      t.integer  :start_tournament_rorder, :last_tournament_rorder
      t.string   :start_tournament_name, :last_tournament_name

      t.timestamps
    end
  end
end
