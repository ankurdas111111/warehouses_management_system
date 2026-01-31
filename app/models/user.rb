class User < ApplicationRecord
  has_secure_password

  has_many :orders, dependent: :nullify
  has_one :wallet, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  after_create :ensure_wallet!

  private

  def ensure_wallet!
    Wallet.create!(user: self, balance_paise: 0) unless wallet
  end
end
