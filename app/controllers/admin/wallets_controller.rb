module Admin
  class WalletsController < BaseController
    def index
      @email = params[:email].to_s.strip.presence
      @user = @email ? User.find_by(email: @email.downcase) : nil
      @wallet = @user&.wallet
    end

    def credit
      email = params[:email].to_s.strip.downcase
      inr = params[:amount_inr].to_s.strip
      amount_paise = (BigDecimal(inr) * 100).to_i
      raise ArgumentError, "amount must be > 0" unless amount_paise.positive?

      user = User.find_by!(email: email)
      Wallets::Transfer.credit!(
        user: user,
        amount_paise: amount_paise,
        reason: "admin_credit",
        idempotency_key: "admin-credit-#{email}-#{Time.current.to_i}"
      )
      AuditLog.record!(
        action: "admin.wallets.credit",
        auditable: user.wallet,
        metadata: { email: email, amount_paise: amount_paise }
      )

      redirect_to admin_wallets_path(email: email), notice: "Wallet credited"
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_wallets_path(email: email), alert: "User not found"
    rescue ArgumentError => e
      redirect_to admin_wallets_path(email: email), alert: e.message
    end
  end
end


