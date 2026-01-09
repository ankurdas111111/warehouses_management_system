class Sku < ApplicationRecord
  has_many :stock_items, dependent: :destroy
  has_many :warehouses, through: :stock_items
  has_many :order_lines, dependent: :restrict_with_exception
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :fulfillment_items, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
