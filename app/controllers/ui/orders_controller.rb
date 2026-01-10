require "securerandom"

module Ui
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
      @idempotency_key = SecureRandom.uuid
      @skus = Sku.order(:code)
    end

    def create
      @skus = Sku.order(:code)
      p = order_params

      idempotency_key = p[:idempotency_key].presence || SecureRandom.uuid
      lines = normalize_lines(p[:lines])

      order =
        Orders::Create.new(
          customer_email: current_user.email,
          idempotency_key: idempotency_key,
          lines: lines,
          user: current_user
        ).call

      redirect_to order_path(order)
    rescue Orders::Error, ActiveRecord::RecordInvalid => e
      @error = e.message
      @idempotency_key = idempotency_key
      @prefill = p
      render :new, status: :unprocessable_entity
    end

    def show
      @order =
        current_user
          .orders
          .includes(
            { order_lines: :sku },
            { inventory_reservations: %i[sku warehouse] },
            { fulfillments: [:warehouse, { fulfillment_items: %i[sku inventory_reservation] }] }
          )
          .find(params[:id])
    end

    private

    def order_params
      params.permit(:idempotency_key, lines: %i[sku_code quantity]).to_h.deep_symbolize_keys
    end

    def normalize_lines(lines)
      (lines || [])
        .select { |l| l.is_a?(Hash) && l[:sku_code].present? && l[:quantity].to_i.positive? }
        .map { |l| { sku_code: l[:sku_code].to_s, quantity: l[:quantity].to_i } }
    end
  end
end


