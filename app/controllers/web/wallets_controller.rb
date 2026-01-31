module Web
  class WalletsController < AuthenticatedController
    def show
      @wallet = current_user.wallet || Wallet.create!(user: current_user, balance_paise: 0)
      @txns = @wallet.wallet_transactions.order(created_at: :desc).limit(50)
    end

    def recharge
      wallet = current_user.wallet || Wallet.create!(user: current_user, balance_paise: 0)
      inr = params[:amount_inr].to_s.strip
      amount_paise = (BigDecimal(inr) * 100).to_i
      raise ArgumentError, "amount must be > 0" unless amount_paise.positive?

      gw_order = DummyGateway.create_order(amount_paise: amount_paise, receipt: "wallet-#{wallet.id}")
      payment =
        Payment.create!(
          amount_paise: amount_paise,
          provider: "dummy_gateway_wallet",
          provider_order_id: gw_order[:id],
          status: :created,
          payable: wallet,
          metadata: { currency: "INR", purpose: "wallet_recharge", user_id: current_user.id }
        )

      redirect_to gateway_checkout_path(payment_id: payment.id)
    rescue ArgumentError, DummyGateway::Error => e
      redirect_to wallet_path, alert: "Recharge failed: #{e.message}"
    end
  end
end
