class CreateStockItems < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_items do |t|
      t.references :sku, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.integer :on_hand, null: false, default: 0
      t.integer :reserved, null: false, default: 0

      t.timestamps

      t.index %i[sku_id warehouse_id], unique: true
      t.check_constraint "on_hand >= 0", name: "stock_items_on_hand_non_negative"
      t.check_constraint "reserved >= 0", name: "stock_items_reserved_non_negative"
      t.check_constraint "reserved <= on_hand", name: "stock_items_reserved_lte_on_hand"
    end
  end
end
