class InventoryReservation < ApplicationRecord
  belongs_to :order
  belongs_to :sku
  belongs_to :warehouse

  enum :status, {
    active: 0,
    released: 1,
    fulfilled: 2
  }

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfilled_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :expires_at, presence: true

  def remaining_quantity
    quantity - fulfilled_quantity
  end
end
