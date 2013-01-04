class AddMemberPullToUser < ActiveRecord::Migration
  def change
    add_column :users, :last_pulled_at, :datetime
    add_column :users, :last_pull, :string
  end
end
