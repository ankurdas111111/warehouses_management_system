module Web
  class PaymentsController < AuthenticatedController
    def new
      @order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      redirect_to order_path(@order), notice: "Order already paid." if @order.paid?

      amount = @order.total_paise

      # Create (or reuse) a provider order + local Payment record (status: created).
      @payment =
        Payment.where(order: @order, provider: "dummy_gateway")
               .order(created_at: :desc)
               .find { |p| p.created? }

      unless @payment
        gw_order = DummyGateway.create_order(amount_paise: amount, receipt: "order-#{@order.id}")
        @payment =
          Payment.create!(
            order: @order,
            payable: @order,
            amount_paise: amount,
            provider: "dummy_gateway",
            provider_order_id: gw_order[:id],
            status: :created,
            metadata: { currency: "INR" }
          )
      end

      @provider_order_id = @payment.provider_order_id
    end

    def wallet
      @order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      redirect_to order_path(@order), notice: "Order already paid." if @order.paid?

      amount = @order.total_paise
      Wallets::Transfer.debit!(
        user: current_user,
        amount_paise: amount,
        reason: "order_payment",
        idempotency_key: "wallet-pay-order-#{@order.id}",
        order: @order
      )
      @order.update!(payment_status: :paid)

      AutoFulfillOrderWorker.perform_in(ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i, @order.id) if ENV["REDIS_URL"].present?
      redirect_to order_path(@order), notice: "Paid using wallet."
    rescue Wallets::Transfer::InsufficientBalance
      redirect_to new_payment_path(order_id: @order.id), alert: "Insufficient wallet balance. Recharge or pay via payment."
    end

    def create
      order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      return redirect_to order_path(order), notice: "Order already paid." if order.paid?
      redirect_to gateway_checkout_path(order_id: order.id)
    end

    # Simulated gateway callback (hosted checkout returns here).
    def callback
      order = current_user.orders.find(params[:order_id])
      return redirect_to order_path(order), notice: "Order already paid." if order.paid?

      provider_order_id = params[:provider_order_id].to_s
      provider_payment_id = params[:provider_payment_id].to_s
      signature = params[:signature].to_s

      payment =
        Payment.find_by!(
          order: order,
          provider: "dummy_gateway",
          provider_order_id: provider_order_id
        )

      DummyGateway.verify!(order_id: provider_order_id, payment_id: provider_payment_id, signature: signature)

      Payment.transaction do
        payment.update!(
          provider_payment_id: provider_payment_id,
          signature: signature,
          status: :captured
        )
        order.update!(payment_status: :paid)
      end

      AutoFulfillOrderWorker.perform_in(ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i, order.id) if ENV["REDIS_URL"].present?
      redirect_to order_path(order), notice: "Payment successful (dummy)."
    rescue DummyGateway::Error => e
      order.update!(payment_status: :payment_failed) if order
      redirect_to new_payment_path(order_id: order.id), alert: "Payment failed: #{e.message}"
    end
  end
end


