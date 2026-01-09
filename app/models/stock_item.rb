class StockItem < ApplicationRecord
  belongs_to :sku
  belongs_to :warehouse

  validates :on_hand, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved, numericality: { greater_than_or_equal_to: 0 }
  validates :sku_id, uniqueness: { scope: :warehouse_id }

  def available
    on_hand - reserved
  end
end
