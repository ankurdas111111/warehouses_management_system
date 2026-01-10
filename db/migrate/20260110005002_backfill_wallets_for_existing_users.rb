class BackfillWalletsForExistingUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    User.find_each do |u|
      Wallet.create!(user_id: u.id, balance_paise: 0) unless Wallet.exists?(user_id: u.id)
    end
  end

  def down
    # no-op
  end
end


