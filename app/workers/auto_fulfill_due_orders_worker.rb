class AutoFulfillDueOrdersWorker
  include Sidekiq::Worker

  sidekiq_options retry: 5

  # Runs periodically (every 4 hours via sidekiq-cron default). Scans for orders that are
  # reserving stock and fulfills only what can be fulfilled safely.
  def perform(limit = 500)
    return if ENV.fetch("AUTO_FULFILL_ENABLED", "1") == "0"

    eligible_order_ids =
      InventoryReservation
        .where(status: :active)
        .joins(:order)
        .merge(Order.where(status: %i[reserved partially_fulfilled], payment_status: :paid))
        .distinct
        .order("orders.id ASC")
        .limit(limit.to_i)
        .pluck("orders.id")

    eligible_order_ids.each do |order_id|
      AutoFulfillOrderWorker.new.perform(order_id)
    rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
      # Skip and let the next periodic run pick it up.
      next
    end
  end
end
