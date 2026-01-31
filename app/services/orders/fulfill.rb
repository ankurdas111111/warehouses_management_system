module Orders
  class Fulfill
    def initialize(order_id:, items:)
      @order_id = order_id
      @items = items
    end

    def call
      validate_inputs!

      ActiveSupport::Notifications.instrument("orders.fulfill", order_id: @order_id, item_count: @items.size) do
        Order.transaction do
        order = Order.lock.find(@order_id)

        raise InvalidTransitionError, "cannot fulfill a cancelled order" if order.cancelled?
        raise InvalidTransitionError, "order already fulfilled" if order.fulfilled?

        reservations = InventoryReservation.where(id: @items.map { |i| i[:reservation_id] })
                                           .order(:id)
                                           .lock
                                           .to_a
                                           .index_by(&:id)

        raise ValidationError, "one or more reservation_id not found" if reservations.size != @items.size

        stock_item_keys = reservations.values.map { |r| [ r.sku_id, r.warehouse_id ] }.uniq
        stock_items = StockItem.where(sku_id: stock_item_keys.map(&:first), warehouse_id: stock_item_keys.map(&:last))
                               .order(:id)
                               .lock
                               .to_a
                               .index_by { |si| [ si.sku_id, si.warehouse_id ] }

        line_by_sku = order.order_lines.index_by(&:sku_id)

        fulfillments_by_wh = {}

        @items.each do |item|
          reservation = reservations.fetch(item[:reservation_id])
          qty = item[:quantity].to_i
          raise ValidationError, "quantity must be > 0" if qty <= 0

          raise ValidationError, "reservation does not belong to order" if reservation.order_id != order.id
          raise InvalidTransitionError, "reservation is not active" unless reservation.active?
          raise ValidationError, "quantity exceeds remaining reservation" if qty > reservation.remaining_quantity

          stock_item = stock_items.fetch([ reservation.sku_id, reservation.warehouse_id ])

          # Decrement both on_hand and reserved when we ship units.
          stock_item.update!(
            on_hand: stock_item.on_hand - qty,
            reserved: stock_item.reserved - qty
          )

          reservation.update!(
            fulfilled_quantity: reservation.fulfilled_quantity + qty,
            status: (reservation.fulfilled_quantity + qty == reservation.quantity) ? :fulfilled : :active
          )

          line = line_by_sku.fetch(reservation.sku_id)
          line.update!(fulfilled_quantity: line.fulfilled_quantity + qty)

          fulfillment = fulfillments_by_wh[reservation.warehouse_id] ||=
            Fulfillment.create!(order: order, warehouse_id: reservation.warehouse_id, status: :pending)

          FulfillmentItem.create!(
            fulfillment: fulfillment,
            inventory_reservation: reservation,
            sku_id: reservation.sku_id,
            quantity: qty
          )

          ActiveSupport::Notifications.instrument(
            "reservation.fulfilled",
            order_id: order.id,
            reservation_id: reservation.id,
            sku_id: reservation.sku_id,
            warehouse_id: reservation.warehouse_id,
            quantity: qty
          )
        end

        fulfillments_by_wh.values.each { |f| f.update!(status: :completed) }

        update_order_status!(order)
        order
        end
      end
    end

    private

    def validate_inputs!
      raise ValidationError, "items must be an array" unless @items.is_a?(Array) && @items.any?
      @items.each do |i|
        raise ValidationError, "each item must include reservation_id and quantity" unless i.is_a?(Hash)
        raise ValidationError, "reservation_id is required" if i[:reservation_id].blank?
      end
    end

    def update_order_status!(order)
      lines = order.order_lines.reload
      if lines.all? { |l| l.fulfilled_quantity >= l.quantity }
        order.update!(status: :fulfilled)
      elsif lines.any? { |l| l.fulfilled_quantity.positive? }
        order.update!(status: :partially_fulfilled)
      else
        order.update!(status: :reserved)
      end
    end
  end
end
