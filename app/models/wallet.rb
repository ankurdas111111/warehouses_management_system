class Wallet < ApplicationRecord
  belongs_to :user
  has_many :wallet_transactions, dependent: :destroy
  has_many :payments, as: :payable, dependent: :nullify

  validates :balance_paise, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
