class CreateWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :wallets do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :balance_paise, null: false, default: 0
      t.timestamps
    end
  end
end
