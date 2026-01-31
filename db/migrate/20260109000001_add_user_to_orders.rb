class AddUserToOrders < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:orders, :user_id)
      add_reference :orders, :user, null: true
    end

    add_index :orders, :user_id, if_not_exists: true
    add_foreign_key :orders, :users, if_not_exists: true
  end
end
