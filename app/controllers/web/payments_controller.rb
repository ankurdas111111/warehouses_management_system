module Web
  class PaymentsController < AuthenticatedController
    def new
      @order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      redirect_to order_path(@order), notice: "Order already paid." if @order.paid?

      amount = @order.total_paise
      ActiveSupport::Notifications.instrument(
        "payments.new",
        user_id: current_user.id,
        order_id: @order.id,
        amount_paise: amount
      )

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
        ActiveSupport::Notifications.instrument(
          "payments.provider_order_created",
          user_id: current_user.id,
          order_id: @order.id,
          payment_id: @payment.id,
          provider: @payment.provider,
          provider_order_id: @payment.provider_order_id
        )
      end

      @provider_order_id = @payment.provider_order_id
    end

    def wallet
      @order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      redirect_to order_path(@order), notice: "Order already paid." if @order.paid?

      amount = @order.total_paise
      ActiveSupport::Notifications.instrument(
        "payments.wallet_attempt",
        user_id: current_user.id,
        order_id: @order.id,
        amount_paise: amount
      )
      Wallets::Transfer.debit!(
        user: current_user,
        amount_paise: amount,
        reason: "order_payment",
        idempotency_key: "wallet-pay-order-#{@order.id}",
        order: @order
      )
      @order.update!(payment_status: :paid)
      ActiveSupport::Notifications.instrument(
        "payments.wallet_success",
        user_id: current_user.id,
        order_id: @order.id,
        amount_paise: amount
      )

      AutoFulfillOrderWorker.perform_in(ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i, @order.id) if ENV["REDIS_URL"].present?
      redirect_to order_path(@order), notice: "Paid using wallet."
    rescue Wallets::Transfer::InsufficientBalance
      ActiveSupport::Notifications.instrument(
        "payments.wallet_failed",
        user_id: current_user.id,
        order_id: @order.id,
        reason: "insufficient_balance"
      )
      redirect_to new_payment_path(order_id: @order.id), alert: "Insufficient wallet balance. Recharge or pay via payment."
    end

    def create
      order = current_user.orders.includes(order_lines: :sku).find(params[:order_id])
      return redirect_to order_path(order), notice: "Order already paid." if order.paid?
      ActiveSupport::Notifications.instrument(
        "payments.checkout_redirect",
        user_id: current_user.id,
        order_id: order.id
      )
      payment =
        Payment.where(order: order, provider: "dummy_gateway")
               .order(created_at: :desc)
               .find { |p| p.created? }

      unless payment
        gw_order = DummyGateway.create_order(amount_paise: order.total_paise, receipt: "order-#{order.id}")
        payment =
          Payment.create!(
            order: order,
            payable: order,
            amount_paise: order.total_paise,
            provider: "dummy_gateway",
            provider_order_id: gw_order[:id],
            status: :created,
            metadata: { currency: "INR" }
          )
      end

      redirect_to gateway_checkout_path(payment_id: payment.id)
    end

    # Simulated gateway callback (hosted checkout returns here).
    def callback
      order = current_user.orders.find(params[:order_id])
      return redirect_to order_path(order), notice: "Order already paid." if order.paid?

      provider_order_id = params[:provider_order_id].to_s
      provider_payment_id = params[:provider_payment_id].to_s
      signature = params[:signature].to_s

      ActiveSupport::Notifications.instrument(
        "payments.callback_received",
        user_id: current_user.id,
        order_id: order.id,
        provider: "dummy_gateway",
        provider_order_id: provider_order_id,
        provider_payment_id_suffix: provider_payment_id.last(6)
      )

      payment =
        Payment.find_by!(
          order: order,
          provider: "dummy_gateway",
          provider_order_id: provider_order_id
        )

      DummyGateway.verify!(order_id: provider_order_id, payment_id: provider_payment_id, signature: signature)
      ActiveSupport::Notifications.instrument(
        "payments.signature_verified",
        user_id: current_user.id,
        order_id: order.id,
        payment_id: payment.id,
        provider_order_id: provider_order_id,
        provider_payment_id_suffix: provider_payment_id.last(6)
      )

      Payment.transaction do
        payment.update!(
          provider_payment_id: provider_payment_id,
          signature: signature,
          status: :captured
        )
        order.update!(payment_status: :paid)
      end
      ActiveSupport::Notifications.instrument(
        "payments.captured",
        user_id: current_user.id,
        order_id: order.id,
        payment_id: payment.id,
        provider_order_id: provider_order_id,
        provider_payment_id_suffix: provider_payment_id.last(6)
      )

      AutoFulfillOrderWorker.perform_in(ENV.fetch("AUTO_FULFILL_DELAY_SECONDS", "300").to_i, order.id) if ENV["REDIS_URL"].present?
      redirect_to order_path(order), notice: "Payment successful (dummy)."
    rescue DummyGateway::Error => e
      order.update!(payment_status: :payment_failed) if order
      ActiveSupport::Notifications.instrument(
        "payments.failed",
        user_id: current_user.id,
        order_id: order&.id,
        provider_order_id: provider_order_id,
        error: e.message.to_s
      )
      redirect_to new_payment_path(order_id: order.id), alert: "Payment failed: #{e.message}"
    end
  end
end
