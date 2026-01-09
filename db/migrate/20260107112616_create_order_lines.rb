class CreateOrderLines < ActiveRecord::Migration[8.1]
  def change
    create_table :order_lines do |t|
      t.references :order, null: false, foreign_key: true
      t.references :sku, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :fulfilled_quantity, null: false, default: 0

      t.timestamps

      t.index %i[order_id sku_id], unique: true
      t.check_constraint "quantity > 0", name: "order_lines_quantity_positive"
      t.check_constraint "fulfilled_quantity >= 0", name: "order_lines_fulfilled_quantity_non_negative"
      t.check_constraint "fulfilled_quantity <= quantity", name: "order_lines_fulfilled_quantity_lte_quantity"
    end
  end
end
