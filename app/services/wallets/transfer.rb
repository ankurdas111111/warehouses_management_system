module Wallets
  class Transfer
    class InsufficientBalance < StandardError; end

    def self.credit!(user:, amount_paise:, reason:, idempotency_key: nil, order: nil, payment: nil)
      amount_paise = amount_paise.to_i
      raise ArgumentError, "amount_paise must be > 0" unless amount_paise.positive?

      user.wallet ||= Wallet.create!(user: user, balance_paise: 0)

      ActiveSupport::Notifications.instrument(
        "wallet.credit",
        user_id: user.id,
        amount_paise: amount_paise,
        reason: reason,
        idempotency_key: idempotency_key,
        order_id: order&.id,
        payment_id: payment&.id
      ) do
        Wallet.transaction do
          wallet = Wallet.lock.find_by!(user_id: user.id)

          if idempotency_key.present? && (existing = WalletTransaction.find_by(idempotency_key: idempotency_key))
            ActiveSupport::Notifications.instrument(
              "wallet.idempotent_hit",
              user_id: user.id,
              kind: "credit",
              idempotency_key: idempotency_key,
              wallet_transaction_id: existing.id
            )
            return existing
          end

          balance_before = wallet.balance_paise
          wallet.update!(balance_paise: balance_before + amount_paise)
          txn =
            WalletTransaction.create!(
              wallet: wallet,
              kind: :credit,
              amount_paise: amount_paise,
              reason: reason,
              idempotency_key: idempotency_key,
              order: order,
              payment: payment
            )
          ActiveSupport::Notifications.instrument(
            "wallet.balance_changed",
            user_id: user.id,
            kind: "credit",
            balance_before_paise: balance_before,
            balance_after_paise: wallet.balance_paise,
            wallet_transaction_id: txn.id
          )
          txn
        end
      end
    end

    def self.debit!(user:, amount_paise:, reason:, idempotency_key: nil, order: nil, payment: nil)
      amount_paise = amount_paise.to_i
      raise ArgumentError, "amount_paise must be > 0" unless amount_paise.positive?

      user.wallet ||= Wallet.create!(user: user, balance_paise: 0)

      ActiveSupport::Notifications.instrument(
        "wallet.debit",
        user_id: user.id,
        amount_paise: amount_paise,
        reason: reason,
        idempotency_key: idempotency_key,
        order_id: order&.id,
        payment_id: payment&.id
      ) do
        Wallet.transaction do
          wallet = Wallet.lock.find_by!(user_id: user.id)

          if idempotency_key.present? && (existing = WalletTransaction.find_by(idempotency_key: idempotency_key))
            ActiveSupport::Notifications.instrument(
              "wallet.idempotent_hit",
              user_id: user.id,
              kind: "debit",
              idempotency_key: idempotency_key,
              wallet_transaction_id: existing.id
            )
            return existing
          end

          if wallet.balance_paise < amount_paise
            ActiveSupport::Notifications.instrument(
              "wallet.insufficient_balance",
              user_id: user.id,
              balance_paise: wallet.balance_paise,
              amount_paise: amount_paise,
              reason: reason,
              order_id: order&.id
            )
            raise InsufficientBalance, "insufficient wallet balance"
          end

          balance_before = wallet.balance_paise
          wallet.update!(balance_paise: balance_before - amount_paise)
          txn =
            WalletTransaction.create!(
              wallet: wallet,
              kind: :debit,
              amount_paise: amount_paise,
              reason: reason,
              idempotency_key: idempotency_key,
              order: order,
              payment: payment
            )
          ActiveSupport::Notifications.instrument(
            "wallet.balance_changed",
            user_id: user.id,
            kind: "debit",
            balance_before_paise: balance_before,
            balance_after_paise: wallet.balance_paise,
            wallet_transaction_id: txn.id
          )
          txn
        end
      end
    end
  end
end


