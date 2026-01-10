class Order < ApplicationRecord
  belongs_to :user, optional: true

  has_many :order_lines, dependent: :destroy
  has_many :inventory_reservations, dependent: :destroy
  has_many :fulfillments, dependent: :destroy
  has_many :payments, dependent: :destroy

  enum :status, {
    pending: 0,
    reserved: 1,
    partially_fulfilled: 2,
    fulfilled: 3,
    cancelled: 4
  }

  enum :payment_status, {
    payment_pending: 0,
    paid: 1,
    payment_failed: 2,
    refunded: 3
  }

  validates :customer_email, presence: true
  validates :idempotency_key, presence: true, uniqueness: true

  def total_paise
    order_lines.includes(:sku).sum { |l| l.quantity.to_i * l.sku.price_cents.to_i }
  end
end
