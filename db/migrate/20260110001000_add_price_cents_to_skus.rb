class AddPriceCentsToSkus < ActiveRecord::Migration[8.1]
  def change
    add_column :skus, :price_cents, :integer, null: false, default: 0
    add_index :skus, :price_cents
  end
end
