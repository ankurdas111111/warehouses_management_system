class CreateFulfillments < ActiveRecord::Migration[8.1]
  def change
    create_table :fulfillments do |t|
      t.references :order, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
