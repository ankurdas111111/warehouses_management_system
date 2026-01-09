class CreateSkus < ActiveRecord::Migration[8.1]
  def change
    create_table :skus do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :skus, :code, unique: true
  end
end
