class AddDeliveryCityToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :delivery_city, :string
    add_index :orders, :delivery_city
  end
end


