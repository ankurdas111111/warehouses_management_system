module Orders
  class Cancel
    def initialize(order_id:)
      @order_id = order_id
    end

    def call
      ActiveSupport::Notifications.instrument("orders.cancel", order_id: @order_id) do
        Order.transaction do
        order = Order.lock.find(@order_id)

        raise InvalidTransitionError, "order already cancelled" if order.cancelled?
        raise InvalidTransitionError, "cannot cancel a fulfilled order" if order.fulfilled?

        reservations =
          order.inventory_reservations
               .where(status: :active)
               .order(:id)
               .lock
               .to_a

        keys = reservations.map { |r| [r.sku_id, r.warehouse_id] }.uniq
        sku_ids = keys.map(&:first)
        warehouse_ids = keys.map(&:last)

        stock_items =
          StockItem.where(sku_id: sku_ids, warehouse_id: warehouse_ids)
                   .order(:id)
                   .lock
                   .to_a
                   .index_by { |si| [si.sku_id, si.warehouse_id] }

        reservations.each do |r|
          release_qty = r.remaining_quantity
          next if release_qty <= 0

          stock_item = stock_items.fetch([r.sku_id, r.warehouse_id])

          stock_item.update!(reserved: stock_item.reserved - release_qty)
          r.update!(status: :released)
          ActiveSupport::Notifications.instrument(
            "reservation.released",
            order_id: order.id,
            reservation_id: r.id,
            sku_id: r.sku_id,
            warehouse_id: r.warehouse_id,
            quantity: release_qty
          )
        end

        # Wallet refund (idempotent): if the order was paid, credit the user's wallet on cancellation.
        if order.paid? && order.user_id.present?
          refund_amount = order.total_paise
          Wallets::Transfer.credit!(
            user: order.user,
            amount_paise: refund_amount,
            reason: "order_refund",
            idempotency_key: "refund-order-#{order.id}",
            order: order
          )
          order.update!(payment_status: :refunded)
        end

        order.update!(status: :cancelled)
        order
        end
      end
    end
  end
end


