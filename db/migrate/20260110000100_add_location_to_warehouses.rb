class AddLocationToWarehouses < ActiveRecord::Migration[8.1]
  def change
    add_column :warehouses, :location, :string
    add_index :warehouses, :location
  end
end
