require "rails_helper"

RSpec.describe Orders::Create, :concurrency do
  it "does not oversell under concurrency" do
    sku = create(:sku, code: "WIDGET", name: "Widget")
    wh1 = create(:warehouse, code: "WH-A", name: "Warehouse A")
    wh2 = create(:warehouse, code: "WH-B", name: "Warehouse B")

    create(:stock_item, sku: sku, warehouse: wh1, on_hand: 5, reserved: 0)
    create(:stock_item, sku: sku, warehouse: wh2, on_hand: 5, reserved: 0)

    n = 20

    mutex = Mutex.new
    cv = ConditionVariable.new
    ready = 0

    successes = 0
    failures = 0

    threads =
      n.times.map do |i|
        Thread.new do
          mutex.synchronize do
            ready += 1
            cv.broadcast if ready == n
            cv.wait(mutex) while ready < n
          end

          ActiveRecord::Base.connection_pool.with_connection do
            begin
              described_class
                .new(
                  customer_email: "buyer@example.com",
                  idempotency_key: "order-#{i}",
                  lines: [ { sku_code: "WIDGET", quantity: 1 } ]
                )
                .call
              mutex.synchronize { successes += 1 }
            rescue Orders::OutOfStockError
              mutex.synchronize { failures += 1 }
            end
          end
        end
      end

    threads.each(&:join)

    expect(successes).to eq(10)
    expect(failures).to eq(10)

    stock_items = StockItem.where(sku: sku)
    stock_items.each do |si|
      expect(si.reserved).to be <= si.on_hand
      expect(si.reserved).to be >= 0
    end

    expect(stock_items.sum(:reserved)).to eq(10)
  end
end
