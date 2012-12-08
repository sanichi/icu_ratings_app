class AddStatusToUsers < ActiveRecord::Migration
  def change
    add_column :users, :status, :string, limit: 20, default: "ok"
  end
end
