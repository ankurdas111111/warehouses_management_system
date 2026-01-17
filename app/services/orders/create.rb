module Orders
  class Create
    AUTO_FULFILL_DELAY_SECONDS = ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i

    def initialize(customer_email:, idempotency_key:, lines:, user: nil, delivery_city: nil)
      @customer_email = customer_email
      @idempotency_key = idempotency_key
      @lines = lines
      @user = user
      @delivery_city = (IndianCities.canonical(delivery_city) || delivery_city).to_s.strip.presence
    end

    def call
      validate_inputs!

      order = nil

      ActiveSupport::Notifications.instrument(
        "orders.create",
        idempotency_key: @idempotency_key,
        line_count: @lines.size,
        user_id: @user&.id,
        delivery_city: @delivery_city
      ) do
        Order.transaction do
          existing = Order.find_by(idempotency_key: @idempotency_key)
          if existing
            order = existing
            next
          end

          order = Order.create!(
            customer_email: @customer_email,
            idempotency_key: @idempotency_key,
            status: :pending,
            user: @user,
            delivery_city: @delivery_city,
            payment_status: :payment_pending
          )
          ActiveSupport::Notifications.instrument(
            "orders.created",
            order_id: order.id,
            user_id: order.user_id,
            delivery_city: order.delivery_city,
            idempotency_key: order.idempotency_key
          )

          order_lines = build_order_lines(order)

          sku_ids = order_lines.map(&:sku_id)
          stock_items = StockItem.where(sku_id: sku_ids).order(:id).lock.to_a
          stock_by_sku = stock_items.group_by(&:sku_id)

          # Distance map used to prefer the nearest warehouse locations to the delivery city.
          # If either city lacks coordinates, distance is nil and those warehouses will be ranked last.
          delivery_coords = @delivery_city.present? ? IndianCities.coords(@delivery_city) : nil
          wh_by_id = Warehouse.where(id: stock_items.map(&:warehouse_id).uniq).select(:id, :location).index_by(&:id)
          distance_by_wh_id =
            if delivery_coords
              wh_by_id.transform_values do |wh|
                IndianCities.distance_km(@delivery_city, wh.location)
              end
            else
              {}
            end

          order_lines.each do |line|
            allocate_for_line!(
              order: order,
              line: line,
              stock_items: stock_by_sku.fetch(line.sku_id, []),
              delivery_city: @delivery_city,
              distance_by_wh_id: distance_by_wh_id
            )
          end

          order.update!(status: :reserved)
        end
      end

      # Fulfillment should happen only after payment is marked as paid.
      order
    rescue ActiveRecord::RecordNotUnique
      order = Order.find_by!(idempotency_key: @idempotency_key)
      enqueue_auto_fulfill(order)
      order
    rescue OutOfStockError => e
      ActiveSupport::Notifications.instrument(
        "orders.create.out_of_stock",
        idempotency_key: @idempotency_key,
        error: e.message
      )
      raise
    end

    private

    def validate_inputs!
      raise ValidationError, "customer_email is required" if @customer_email.blank?
      raise ValidationError, "idempotency_key is required" if @idempotency_key.blank?
      raise ValidationError, "lines must be an array" unless @lines.is_a?(Array) && @lines.any?

      @lines.each do |l|
        raise ValidationError, "each line must include sku_code and quantity" unless l.is_a?(Hash)
        raise ValidationError, "sku_code is required" if l[:sku_code].blank?
        qty = l[:quantity].to_i
        raise ValidationError, "quantity must be > 0" if qty <= 0
      end
    end

    def build_order_lines(order)
      sku_codes = @lines.map { |l| l[:sku_code].to_s }
      skus_by_code = Sku.where(code: sku_codes).index_by(&:code)
      missing = sku_codes.uniq - skus_by_code.keys
      raise ValidationError, "unknown sku_code(s): #{missing.join(', ')}" if missing.any?

      @lines.map do |l|
        sku = skus_by_code.fetch(l[:sku_code].to_s)
        OrderLine.create!(
          order: order,
          sku: sku,
          quantity: l[:quantity].to_i,
          fulfilled_quantity: 0
        )
      end
    end

    def allocate_for_line!(order:, line:, stock_items:, delivery_city:, distance_by_wh_id:)
      needed = line.quantity

      candidates =
        stock_items
          .select { |si| si.available.positive? }
          .sort_by do |si|
            # Prefer nearer warehouses first. If distance is unknown, treat as far away.
            distance = distance_by_wh_id[si.warehouse_id]
            distance_rank = distance.nil? ? 1 : 0

            # If no distance info exists at all, fall back to exact city match preference.
            exact_city_rank =
              if distance_by_wh_id.empty? && delivery_city.present?
                (Warehouse.where(id: si.warehouse_id).pick(:location).to_s == delivery_city) ? 0 : 1
              else
                0
              end

            [distance_rank, exact_city_rank, (distance || 9_999_999), -si.available, si.warehouse_id]
          end

      candidates.each do |stock_item|
        break if needed <= 0

        take = [stock_item.available, needed].min
        next if take <= 0

        distance_km = distance_by_wh_id[stock_item.warehouse_id]
        reservation =
          InventoryReservation.create!(
          order: order,
          sku_id: line.sku_id,
          warehouse_id: stock_item.warehouse_id,
          quantity: take,
          fulfilled_quantity: 0,
          status: :active
        )

        stock_item.update!(reserved: stock_item.reserved + take)
        ActiveSupport::Notifications.instrument(
          "reservation.created",
          order_id: order.id,
          order_line_id: line.id,
          reservation_id: reservation.id,
          sku_id: line.sku_id,
          warehouse_id: stock_item.warehouse_id,
          quantity: take,
          delivery_city: delivery_city,
          distance_km: distance_km
        )
        needed -= take
      end

      raise OutOfStockError, "insufficient inventory for sku_id=#{line.sku_id}" if needed.positive?
    end

  end
end


