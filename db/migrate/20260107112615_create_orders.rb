class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.integer :status, null: false, default: 0
      t.string :customer_email, null: false
      t.string :idempotency_key, null: false

      t.timestamps
    end

    add_index :orders, :idempotency_key, unique: true
  end
end
