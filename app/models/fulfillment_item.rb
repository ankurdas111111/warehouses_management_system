class FulfillmentItem < ApplicationRecord
  belongs_to :fulfillment
  belongs_to :inventory_reservation
  belongs_to :sku

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
