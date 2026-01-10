class WalletTransaction < ApplicationRecord
  belongs_to :wallet
  belongs_to :order, optional: true
  belongs_to :payment, optional: true

  enum :kind, { credit: 0, debit: 1 }

  validates :reason, presence: true
  validates :amount_paise, numericality: { only_integer: true, greater_than: 0 }
end


