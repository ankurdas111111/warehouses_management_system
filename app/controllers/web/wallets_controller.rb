module Web
  class WalletsController < AuthenticatedController
    def show
      @wallet = current_user.wallet || Wallet.create!(user: current_user, balance_paise: 0)
      @txns = @wallet.wallet_transactions.order(created_at: :desc).limit(50)
    end

    def recharge
      wallet = current_user.wallet || Wallet.create!(user: current_user, balance_paise: 0)
      require "securerandom"
      inr = params[:amount_inr].to_s.strip
      amount_paise = (BigDecimal(inr) * 100).to_i
      raise ArgumentError, "amount must be > 0" unless amount_paise.positive?

      gw_order = DummyGateway.create_order(amount_paise: amount_paise, receipt: "wallet-#{wallet.id}")
      payment_id = "pay_#{SecureRandom.hex(10)}"
      signature = DummyGateway.signature_for(order_id: gw_order[:id], payment_id: payment_id)
      DummyGateway.verify!(order_id: gw_order[:id], payment_id: payment_id, signature: signature)

      Payment.transaction do
        payment =
          Payment.create!(
            amount_paise: amount_paise,
            provider: "dummy_gateway_wallet",
            provider_order_id: gw_order[:id],
            provider_payment_id: payment_id,
            signature: signature,
            status: :captured,
            payable: wallet,
            metadata: { currency: "INR", purpose: "wallet_recharge", user_id: current_user.id }
          )

        Wallets::Transfer.credit!(
          user: current_user,
          amount_paise: amount_paise,
          reason: "wallet_recharge",
          idempotency_key: "wallet-topup-#{payment.provider_order_id}",
          payment: payment
        )
      end

      redirect_to wallet_path, notice: "Wallet recharged."
    rescue ArgumentError, DummyGateway::Error => e
      redirect_to wallet_path, alert: "Recharge failed: #{e.message}"
    end
  end
end


