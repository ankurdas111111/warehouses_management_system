require "rails_helper"

RSpec.describe "Orders API", type: :request do
  it "creates an order and reserves across warehouses" do
    sku = create(:sku, code: "WIDGET", name: "Widget")
    wh1 = create(:warehouse, code: "WH-A", name: "Warehouse A")
    wh2 = create(:warehouse, code: "WH-B", name: "Warehouse B")

    create(:stock_item, sku: sku, warehouse: wh1, on_hand: 2, reserved: 0)
    create(:stock_item, sku: sku, warehouse: wh2, on_hand: 2, reserved: 0)

    post "/api/orders",
         params: {
           customer_email: "buyer@example.com",
           lines: [ { sku_code: "WIDGET", quantity: 3 } ]
         },
         headers: { "Idempotency-Key" => "order-abc" }

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("reserved")
    expect(body["lines"].first["quantity"]).to eq(3)
    expect(body["reservations"].sum { |r| r["quantity"] }).to eq(3)

    # idempotent retry returns same order
    post "/api/orders",
         params: {
           customer_email: "buyer@example.com",
           lines: [ { sku_code: "WIDGET", quantity: 3 } ]
         },
         headers: { "Idempotency-Key" => "order-abc" }

    expect(response).to have_http_status(:ok)
    body2 = JSON.parse(response.body)
    expect(body2["id"]).to eq(body["id"])
  end
end
