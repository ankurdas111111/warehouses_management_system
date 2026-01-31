require "securerandom"

module Web
  class OrdersController < AuthenticatedController
    def index
      @orders =
        current_user
          .orders
          .order(created_at: :desc)
          .limit(50)
          .includes(order_lines: :sku)
    end

    def new
      load_order_form_context!
    end

    def create
      p = order_params

      idempotency_key = p[:idempotency_key].presence || SecureRandom.uuid
      lines = normalize_lines(p[:lines])

      order =
        Orders::Create.new(
          customer_email: current_user.email,
          idempotency_key: idempotency_key,
          lines: lines,
          user: current_user,
          delivery_city: p[:delivery_city]
        ).call

      redirect_to new_payment_path(order_id: order.id)
    rescue Orders::Error, ActiveRecord::RecordInvalid => e
      @error = e.message
      @prefill = p
      @idempotency_key = idempotency_key
      load_order_form_context!
      render :new, status: :unprocessable_entity
    end

    def show
      @order =
        current_user
          .orders
          .includes(
            { order_lines: :sku },
            { inventory_reservations: %i[sku warehouse] },
            { fulfillments: [ :warehouse, { fulfillment_items: %i[sku inventory_reservation] } ] }
          )
          .find(params[:id])
    end

    def cancel
      order = current_user.orders.find(params[:id])
      Orders::Cancel.new(order_id: order.id).call
      redirect_to order_path(order), notice: "Order cancelled."
    rescue Orders::Error, ActiveRecord::RecordInvalid => e
      redirect_to order_path(order), alert: e.message
    end

    private

    def order_params
      params.permit(:idempotency_key, :delivery_city, lines: %i[sku_code quantity]).to_h.deep_symbolize_keys
    end

    def load_order_form_context!
      @skus = Sku.order(:code)
      @idempotency_key ||= SecureRandom.uuid

      rows =
        StockItem
          .joins(:sku, :warehouse)
          .select(
            "skus.code AS sku_code, " \
            "skus.name AS sku_name, " \
            "skus.price_cents AS price_cents, " \
            "warehouses.location AS location, " \
            "stock_items.on_hand AS on_hand, " \
            "stock_items.reserved AS reserved"
          )

      @availability =
        rows
          .map do |r|
            available = r.on_hand.to_i - r.reserved.to_i
            [ r.sku_code, r.sku_name, r.price_cents.to_i, r.location.to_s, available ]
          end
          .group_by { |sku_code, _name, _price, _loc, _avail| sku_code }
    end

    def normalize_lines(lines)
      (lines || [])
        .select { |l| l.is_a?(Hash) && l[:sku_code].present? && l[:quantity].to_i.positive? }
        .map { |l| { sku_code: l[:sku_code].to_s, quantity: l[:quantity].to_i } }
    end
  end
end
