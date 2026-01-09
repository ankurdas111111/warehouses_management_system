class Fulfillment < ApplicationRecord
  belongs_to :order
  belongs_to :warehouse

  has_many :fulfillment_items, dependent: :destroy

  enum :status, {
    pending: 0,
    completed: 1
  }
end
