module Web
  class GatewayController < AuthenticatedController
    def show
      @order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      redirect_to order_path(@order), notice: "Order already paid." if @order.paid?

      @payment =
        Payment.where(order: @order, provider: "dummy_gateway")
               .order(created_at: :desc)
               .first

      unless @payment&.created?
        ActiveSupport::Notifications.instrument(
          "gateway.session_invalid",
          user_id: current_user.id,
          order_id: @order.id,
          payment_id: @payment&.id
        )
        redirect_to new_payment_path(order_id: @order.id), alert: "Checkout session expired. Please try again."
        return
      end

      ActiveSupport::Notifications.instrument(
        "gateway.show",
        user_id: current_user.id,
        order_id: @order.id,
        payment_id: @payment.id,
        provider_order_id: @payment.provider_order_id
      )
    end

    def pay
      order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      return redirect_to order_path(order), notice: "Order already paid." if order.paid?

      payment =
        Payment.where(order: order, provider: "dummy_gateway")
               .order(created_at: :desc)
               .first

      unless payment&.created?
        ActiveSupport::Notifications.instrument(
          "gateway.session_invalid",
          user_id: current_user.id,
          order_id: order.id,
          payment_id: payment&.id
        )
        return redirect_to new_payment_path(order_id: order.id), alert: "Checkout session expired. Please try again."
      end

      if params[:simulate_failure].present?
        ActiveSupport::Notifications.instrument(
          "gateway.simulate_failure",
          user_id: current_user.id,
          order_id: order.id,
          payment_id: payment.id,
          provider_order_id: payment.provider_order_id
        )
        Payment.transaction do
          payment.update!(status: :failed)
          order.update!(payment_status: :payment_failed)
        end
        return redirect_to new_payment_path(order_id: order.id), alert: "Payment failed (dummy)."
      end

      provider_payment_id = "pay_#{SecureRandom.hex(10)}"
      signature = DummyGateway.signature_for(order_id: payment.provider_order_id, payment_id: provider_payment_id)

      ActiveSupport::Notifications.instrument(
        "gateway.pay_redirect",
        user_id: current_user.id,
        order_id: order.id,
        payment_id: payment.id,
        provider_order_id: payment.provider_order_id,
        provider_payment_id_suffix: provider_payment_id.last(6)
      )
      redirect_to payment_callback_path(
        order_id: order.id,
        provider_order_id: payment.provider_order_id,
        provider_payment_id: provider_payment_id,
        signature: signature
      )
    end
  end
end


