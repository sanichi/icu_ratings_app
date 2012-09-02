class AddReasonToRatingRun < ActiveRecord::Migration
  def change
    add_column :rating_runs, :reason, :string, limit: 100, default: "", null: false
  end
end
