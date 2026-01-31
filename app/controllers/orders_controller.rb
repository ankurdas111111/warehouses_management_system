class OrdersController < ApplicationController
  def create
    idempotency_key = request.headers["Idempotency-Key"] || params[:idempotency_key]
    if idempotency_key.present? && (existing = Order.find_by(idempotency_key: idempotency_key))
      return render json: serialize_order(existing), status: :ok
    end

    p = create_params
    service =
      Orders::Create.new(
        customer_email: p[:customer_email],
        idempotency_key: idempotency_key,
        lines: p[:lines],
        delivery_city: p[:delivery_city]
      )

    order = service.call
    render json: serialize_order(order), status: :created
  end

  def show
    order = Order.includes(:order_lines, :inventory_reservations, :fulfillments).find(params[:id])
    render json: serialize_order(order)
  end

  def cancel
    order = Orders::Cancel.new(order_id: params[:id]).call
    render json: serialize_order(order)
  end

  def fulfill
    order = Orders::Fulfill.new(order_id: params[:id], items: fulfill_params[:items]).call
    render json: serialize_order(order)
  end

  private

  def create_params
    params.permit(:customer_email, :delivery_city, lines: %i[sku_code quantity]).to_h.deep_symbolize_keys
  end

  def fulfill_params
    params.permit(items: %i[reservation_id quantity]).to_h.deep_symbolize_keys
  end

  def serialize_order(order)
    order.reload
    lines = order.order_lines.includes(:sku).order(:id)
    reservations = order.inventory_reservations.includes(:sku, :warehouse).order(:id)

    {
      id: order.id,
      status: order.status,
      customer_email: order.customer_email,
      delivery_city: order.delivery_city,
      payment_status: order.payment_status,
      created_at: order.created_at,
      lines: lines.map do |l|
        {
          id: l.id,
          sku_id: l.sku_id,
          sku_code: l.sku.code,
          quantity: l.quantity,
          fulfilled_quantity: l.fulfilled_quantity
        }
      end,
      reservations: reservations.map do |r|
        {
          id: r.id,
          sku_id: r.sku_id,
          sku_code: r.sku.code,
          warehouse_id: r.warehouse_id,
          warehouse_code: r.warehouse.code,
          quantity: r.quantity,
          fulfilled_quantity: r.fulfilled_quantity,
          status: r.status
        }
      end
    }
  end
end
