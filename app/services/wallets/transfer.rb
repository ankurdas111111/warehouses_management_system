module Wallets
  class Transfer
    class InsufficientBalance < StandardError; end

    def self.credit!(user:, amount_paise:, reason:, idempotency_key: nil, order: nil, payment: nil)
      amount_paise = amount_paise.to_i
      raise ArgumentError, "amount_paise must be > 0" unless amount_paise.positive?

      user.wallet ||= Wallet.create!(user: user, balance_paise: 0)

      Wallet.transaction do
        wallet = Wallet.lock.find_by!(user_id: user.id)

        if idempotency_key.present? && (existing = WalletTransaction.find_by(idempotency_key: idempotency_key))
          return existing
        end

        wallet.update!(balance_paise: wallet.balance_paise + amount_paise)
        WalletTransaction.create!(
          wallet: wallet,
          kind: :credit,
          amount_paise: amount_paise,
          reason: reason,
          idempotency_key: idempotency_key,
          order: order,
          payment: payment
        )
      end
    end

    def self.debit!(user:, amount_paise:, reason:, idempotency_key: nil, order: nil, payment: nil)
      amount_paise = amount_paise.to_i
      raise ArgumentError, "amount_paise must be > 0" unless amount_paise.positive?

      user.wallet ||= Wallet.create!(user: user, balance_paise: 0)

      Wallet.transaction do
        wallet = Wallet.lock.find_by!(user_id: user.id)

        if idempotency_key.present? && (existing = WalletTransaction.find_by(idempotency_key: idempotency_key))
          return existing
        end

        raise InsufficientBalance, "insufficient wallet balance" if wallet.balance_paise < amount_paise

        wallet.update!(balance_paise: wallet.balance_paise - amount_paise)
        WalletTransaction.create!(
          wallet: wallet,
          kind: :debit,
          amount_paise: amount_paise,
          reason: reason,
          idempotency_key: idempotency_key,
          order: order,
          payment: payment
        )
      end
    end
  end
end


