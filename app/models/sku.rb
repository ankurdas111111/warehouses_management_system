class Sku < ApplicationRecord
  has_many :stock_items, dependent: :destroy
  has_many :warehouses, through: :stock_items
  has_many :order_lines, dependent: :restrict_with_exception
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :fulfillment_items, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Stored as "cents" but treated as paise (INR minor unit) throughout the app.
  def price_inr
    price_cents.to_i / 100.0
  end

  def price_inr_display
    format("₹%.2f", price_inr)
  end
end
