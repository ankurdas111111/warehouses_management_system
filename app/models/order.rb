class Order < ApplicationRecord
  belongs_to :user, optional: true

  has_many :order_lines, dependent: :destroy
  has_many :inventory_reservations, dependent: :destroy
  has_many :fulfillments, dependent: :destroy

  enum :status, {
    pending: 0,
    reserved: 1,
    partially_fulfilled: 2,
    fulfilled: 3,
    cancelled: 4
  }

  validates :customer_email, presence: true
  validates :idempotency_key, presence: true, uniqueness: true
end
