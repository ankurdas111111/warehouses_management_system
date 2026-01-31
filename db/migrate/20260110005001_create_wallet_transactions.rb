class CreateWalletTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :wallet_transactions do |t|
      t.references :wallet, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0 # credit/debit
      t.integer :amount_paise, null: false
      t.string :reason, null: false
      t.string :idempotency_key
      t.references :order, foreign_key: true, null: true
      t.references :payment, foreign_key: true, null: true
      t.timestamps
    end

    add_index :wallet_transactions, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
  end
end
