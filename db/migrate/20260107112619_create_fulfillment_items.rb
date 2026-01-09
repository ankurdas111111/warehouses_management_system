class CreateFulfillmentItems < ActiveRecord::Migration[8.1]
  def change
    create_table :fulfillment_items do |t|
      t.references :fulfillment, null: false, foreign_key: true
      t.references :inventory_reservation, null: false, foreign_key: true
      t.references :sku, null: false, foreign_key: true
      t.integer :quantity, null: false

      t.timestamps

      t.index %i[fulfillment_id inventory_reservation_id], unique: true, name: "idx_fi_fulfillment_reservation_unique"
      t.check_constraint "quantity > 0", name: "fulfillment_items_quantity_positive"
    end
  end
end
