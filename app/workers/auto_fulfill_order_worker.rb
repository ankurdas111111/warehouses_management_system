class AutoFulfillOrderWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    ActiveSupport::Notifications.instrument("orders.auto_fulfill", order_id: order.id) do
      # Lock the order row so concurrent workers don't race each other.
      Order.transaction do
        order = Order.lock.find(order.id)

        return if order.cancelled? || order.fulfilled?
        return unless order.paid?
        return unless order.reserved? || order.partially_fulfilled?

        active_reservations =
          order.inventory_reservations
               .where(status: :active)
               .order(:id)
               .lock
               .to_a

        items =
          active_reservations
            .map { |r| { reservation_id: r.id, quantity: r.remaining_quantity } }
            .select { |i| i[:quantity].to_i.positive? }

        return if items.empty?

        Orders::Fulfill.new(order_id: order.id, items: items).call
      end
    end
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
    raise
  end
end


