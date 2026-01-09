class CreateInventoryReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_reservations do |t|
      t.references :order, null: false, foreign_key: true
      t.references :sku, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :fulfilled_quantity, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false

      t.timestamps

      t.index %i[order_id sku_id warehouse_id], name: "idx_reservations_order_sku_wh"
      t.check_constraint "quantity > 0", name: "inventory_reservations_quantity_positive"
      t.check_constraint "fulfilled_quantity >= 0", name: "inventory_reservations_fulfilled_quantity_non_negative"
      t.check_constraint "fulfilled_quantity <= quantity", name: "inventory_reservations_fulfilled_quantity_lte_quantity"
    end
  end
end
