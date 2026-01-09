class ReservationExpiryJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 500

  def perform
    loop do
      ids = InventoryReservation.where(status: :active)
                               .where("expires_at <= ?", Time.current)
                               .limit(BATCH_SIZE)
                               .pluck(:id)

      break if ids.empty?

      ids.each { |id| expire_one!(id) }
    end
  end

  private

  def expire_one!(reservation_id)
    InventoryReservation.transaction do
      r = InventoryReservation.lock.find(reservation_id)
      return unless r.active? && r.expires_at <= Time.current

      release_qty = r.remaining_quantity
      return if release_qty <= 0

      stock_item = StockItem.where(sku_id: r.sku_id, warehouse_id: r.warehouse_id).lock.first
      return unless stock_item

      stock_item.update!(reserved: stock_item.reserved - release_qty)
      r.update!(status: :released)
    end
  end
end


