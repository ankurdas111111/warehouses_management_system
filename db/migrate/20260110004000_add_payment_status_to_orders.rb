class AddPaymentStatusToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :payment_status, :integer, null: false, default: 0
    add_index :orders, :payment_status
  end
end
