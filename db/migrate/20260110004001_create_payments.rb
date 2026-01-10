class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.integer :amount_paise, null: false
      t.string :provider, null: false
      t.string :provider_order_id, null: false
      t.string :provider_payment_id
      t.string :signature
      t.integer :status, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :payments, %i[provider provider_order_id], unique: true
  end
end


