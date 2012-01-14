class AddUserSalt < ActiveRecord::Migration
  def up
    add_column :users, :salt, :string, limit: 32
    change_column :users, :password, :string, limit: 32
  end
  
  def down
    remove_column :users, :salt
    change_column :users, :password, :string, limit: 20
  end
end
