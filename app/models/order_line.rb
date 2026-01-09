class OrderLine < ApplicationRecord
  belongs_to :order
  belongs_to :sku

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfilled_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
