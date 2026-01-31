module Web
  class GatewayController < AuthenticatedController
    def show
      load_payment_context!

      return redirect_to order_path(@order), notice: "Order already paid." if @order&.paid?

      unless @payment&.created?
        ActiveSupport::Notifications.instrument(
          "gateway.session_invalid",
          user_id: current_user.id,
          order_id: @order&.id,
          payment_id: @payment&.id,
          payable_type: @payment&.payable_type
        )
        return redirect_to(back_path, alert: "Checkout session expired. Please try again.")
      end

      ActiveSupport::Notifications.instrument(
        "gateway.show",
        user_id: current_user.id,
        order_id: @order&.id,
        payment_id: @payment.id,
        provider_order_id: @payment.provider_order_id,
        payable_type: @payment.payable_type
      )
    end

    def pay
      load_payment_context!

      return redirect_to order_path(@order), notice: "Order already paid." if @order&.paid?

      unless @payment&.created?
        ActiveSupport::Notifications.instrument(
          "gateway.session_invalid",
          user_id: current_user.id,
          order_id: @order&.id,
          payment_id: @payment&.id,
          payable_type: @payment&.payable_type
        )
        return redirect_to(back_path, alert: "Checkout session expired. Please try again.")
      end

      if params[:simulate_failure].present?
        ActiveSupport::Notifications.instrument(
          "gateway.simulate_failure",
          user_id: current_user.id,
          order_id: @order&.id,
          payment_id: @payment.id,
          provider_order_id: @payment.provider_order_id,
          payable_type: @payment.payable_type
        )

        Payment.transaction do
          @payment.update!(status: :failed)
          @order&.update!(payment_status: :payment_failed)
        end
        return redirect_to(back_path, alert: "Payment failed (dummy).")
      end

      validation_errors = validate_card_inputs(params)
      if validation_errors.any?
        ActiveSupport::Notifications.instrument(
          "gateway.validation_failed",
          user_id: current_user.id,
          order_id: @order&.id,
          payment_id: @payment.id,
          provider_order_id: @payment.provider_order_id,
          payable_type: @payment.payable_type,
          error_count: validation_errors.size
        )
        @errors = validation_errors
        return render :show, status: :unprocessable_entity
      end

      provider_payment_id = "pay_#{SecureRandom.hex(10)}"
      signature = DummyGateway.signature_for(order_id: @payment.provider_order_id, payment_id: provider_payment_id)

      if @payment.payable_type == "Wallet"
        Payment.transaction do
          @payment.update!(
            provider_payment_id: provider_payment_id,
            signature: signature,
            status: :captured
          )

          Wallets::Transfer.credit!(
            user: current_user,
            amount_paise: @payment.amount_paise,
            reason: "wallet_recharge",
            idempotency_key: "wallet-topup-#{@payment.provider_order_id}",
            payment: @payment
          )
        end

        return redirect_to wallet_path, notice: "Wallet recharged."
      end

      ActiveSupport::Notifications.instrument(
        "gateway.pay_redirect",
        user_id: current_user.id,
        order_id: @order&.id,
        payment_id: @payment.id,
        provider_order_id: @payment.provider_order_id,
        provider_payment_id_suffix: provider_payment_id.last(6),
        payable_type: @payment.payable_type
      )
      redirect_to payment_callback_path(
        order_id: @order.id,
        provider_order_id: @payment.provider_order_id,
        provider_payment_id: provider_payment_id,
        signature: signature
      )
    end

    private

    def load_payment_context!
      payment_id = params[:payment_id].to_i
      raise ActiveRecord::RecordNotFound, "payment_id is required" if payment_id <= 0

      @payment = Payment.find(payment_id)

      # Authorize access:
      # - Order checkout: payment belongs to an order owned by current_user
      # - Wallet recharge: payment belongs to current_user's wallet
      @order = @payment.order

      if @order.present?
        raise ActiveRecord::RecordNotFound unless @order.user_id == current_user.id
        return
      end

      if @payment.payable_type == "Wallet"
        wallet = @payment.payable
        raise ActiveRecord::RecordNotFound unless wallet.is_a?(Wallet) && wallet.user_id == current_user.id
        return
      end

      raise ActiveRecord::RecordNotFound
    end

    def back_path
      return new_payment_path(order_id: @order.id) if @order.present?
      return wallet_path if @payment&.payable_type == "Wallet"
      root_path
    end

    def validate_card_inputs(p)
      errors = []

      cardholder_name = p[:cardholder_name].to_s.strip
      errors << "Cardholder name is required." if cardholder_name.blank?

      number = p[:card_number].to_s.gsub(/[^\d]/, "")
      if number.blank?
        errors << "Card number is required."
      elsif number.length != 16
        errors << "Card number must be 16 digits."
      elsif !luhn_valid?(number)
        errors << "Card number looks invalid."
      end

      expiry_raw = p[:expiry].to_s.strip
      if expiry_raw.blank?
        errors << "Expiry is required."
      else
        expiry_match = expiry_raw.match(/\A(\d{1,2})\s*\/\s*(\d{2}|\d{4})\z/)
        if expiry_match.nil?
          errors << "Expiry must be in MM/YY format."
        else
          month = expiry_match[1].to_i
          year = expiry_match[2].to_i
          year += 2000 if year < 100

          if month < 1 || month > 12
            errors << "Expiry month must be between 01 and 12."
          else
            today = Date.current
            exp_date = Date.new(year, month, 1).end_of_month
            errors << "Card has expired." if exp_date < today
          end
        end
      end

      cvv = p[:cvv].to_s.gsub(/[^\d]/, "")
      if cvv.blank?
        errors << "CVV is required."
      elsif cvv.length != 3
        errors << "CVV must be 3 digits."
      end

      errors
    end

    def luhn_valid?(digits)
      sum = 0
      digits.reverse.each_char.with_index do |ch, idx|
        n = ch.ord - 48
        if idx.odd?
          n *= 2
          n -= 9 if n > 9
        end
        sum += n
      end
      (sum % 10).zero?
    end
  end
end
