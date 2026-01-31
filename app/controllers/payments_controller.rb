class PaymentsController < ApplicationController
  def create_order
    order = Order.find(params[:order_id])
    amount = order.total_paise
    gw_order = DummyGateway.create_order(amount_paise: amount, receipt: "order-#{order.id}")

    Payment.create!(
      order: order,
      payable: order,
      amount_paise: amount,
      provider: "dummy_gateway",
      provider_order_id: gw_order[:id],
      status: :created,
      metadata: { currency: "INR" }
    )

    render json: {
      key_id: DummyGateway.key_id,
      order_id: gw_order[:id],
      amount: amount,
      currency: "INR"
    }
  end

  def verify
    order = Order.find(params[:order_id])
    provider_order_id = params[:provider_order_id].to_s
    payment_id = params[:provider_payment_id].to_s
    signature = params[:signature].to_s

    DummyGateway.verify!(order_id: provider_order_id, payment_id: payment_id, signature: signature)

    payment =
      Payment.find_by!(
        provider: [ "dummy_gateway", "legacy_dummy_gateway" ],
        provider_order_id: provider_order_id,
        order_id: order.id
      )
    payment.update!(provider_payment_id: payment_id, signature: signature, status: :captured)
    order.update!(payment_status: :paid)

    AutoFulfillOrderWorker.perform_in(ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i, order.id) if ENV["REDIS_URL"].present?

    render json: { status: "paid", order_id: order.id, provider_order_id: provider_order_id, provider_payment_id: payment_id }
  rescue DummyGateway::Error => e
    order.update!(payment_status: :payment_failed) if order
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
