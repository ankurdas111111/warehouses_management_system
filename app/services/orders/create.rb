module Orders
  class Create
    RESERVATION_TTL = 30.minutes

    def initialize(customer_email:, idempotency_key:, lines:)
      @customer_email = customer_email
      @idempotency_key = idempotency_key
      @lines = lines
    end

    def call
      validate_inputs!

      ActiveSupport::Notifications.instrument(
        "orders.create",
        customer_email: @customer_email,
        idempotency_key: @idempotency_key,
        line_count: @lines.size
      ) do
        Order.transaction do
        existing = Order.find_by(idempotency_key: @idempotency_key)
        return existing if existing

        order = Order.create!(
          customer_email: @customer_email,
          idempotency_key: @idempotency_key,
          status: :pending
        )

        order_lines = build_order_lines(order)

        sku_ids = order_lines.map(&:sku_id)
        stock_items = StockItem.where(sku_id: sku_ids).order(:id).lock.to_a
        stock_by_sku = stock_items.group_by(&:sku_id)

        expires_at = Time.current + RESERVATION_TTL

        order_lines.each do |line|
          allocate_for_line!(
            order: order,
            line: line,
            stock_items: stock_by_sku.fetch(line.sku_id, []),
            expires_at: expires_at
          )
        end

        order.update!(status: :reserved)
        order
        end
      end
    rescue ActiveRecord::RecordNotUnique
      Order.find_by!(idempotency_key: @idempotency_key)
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

    def allocate_for_line!(order:, line:, stock_items:, expires_at:)
      needed = line.quantity

      candidates =
        stock_items
          .select { |si| si.available.positive? }
          .sort_by { |si| [-si.available, si.warehouse_id] }

      candidates.each do |stock_item|
        break if needed <= 0

        take = [stock_item.available, needed].min
        next if take <= 0

        reservation =
          InventoryReservation.create!(
          order: order,
          sku_id: line.sku_id,
          warehouse_id: stock_item.warehouse_id,
          quantity: take,
          fulfilled_quantity: 0,
          status: :active,
          expires_at: expires_at
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
          expires_at: expires_at
        )
        needed -= take
      end

      raise OutOfStockError, "insufficient inventory for sku_id=#{line.sku_id}" if needed.positive?
    end
  end
end


