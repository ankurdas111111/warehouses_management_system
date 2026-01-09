class Warehouse < ApplicationRecord
  has_many :stock_items, dependent: :destroy
  has_many :skus, through: :stock_items
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :fulfillments, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :location, presence: true
end
