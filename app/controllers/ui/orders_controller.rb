require "securerandom"

module Ui
  class OrdersController < BaseController
    def index
      @customer_email = params[:customer_email].to_s.strip.presence

      session_order_ids = Array(session[:order_ids]).map(&:to_i).uniq
      session_scope = Order.where(id: session_order_ids)

      email_scope = @customer_email ? Order.where(customer_email: @customer_email) : Order.none

      @orders =
        Order.where(id: (session_scope.select(:id)).or(email_scope.select(:id)))
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
          customer_email: p[:customer_email],
          idempotency_key: idempotency_key,
          lines: lines
        ).call

      session[:order_ids] = (Array(session[:order_ids]) + [order.id]).uniq

      redirect_to ui_order_path(order)
    rescue Orders::Error, ActiveRecord::RecordInvalid => e
      @error = e.message
      @idempotency_key = idempotency_key
      @prefill = p
      render :new, status: :unprocessable_entity
    end

    def show
      @order = Order.includes(order_lines: :sku, inventory_reservations: %i[sku warehouse]).find(params[:id])
    end

    private

    def order_params
      params.permit(:customer_email, :idempotency_key, lines: %i[sku_code quantity]).to_h.deep_symbolize_keys
    end

    def normalize_lines(lines)
      (lines || [])
        .select { |l| l.is_a?(Hash) && l[:sku_code].present? && l[:quantity].to_i.positive? }
        .map { |l| { sku_code: l[:sku_code].to_s, quantity: l[:quantity].to_i } }
    end
  end
end


