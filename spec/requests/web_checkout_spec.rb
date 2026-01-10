require "rails_helper"

RSpec.describe "Web checkout flow", type: :request do
  def login!(email:, password:)
    post "/login", params: { email: email, password: password }
    expect(response).to have_http_status(:found)
    follow_redirect!
  end

  it "re-renders order form with a 422 (not 500) when out of stock" do
    user = User.create!(email: "test@example.com", password: "password", password_confirmation: "password")
    login!(email: user.email, password: "password")

    sku = create(:sku, code: "WIDGET", name: "Widget", price_cents: 1000)
    wh = create(:warehouse, code: "WH-A", name: "Warehouse A", location: "Mumbai")
    create(:stock_item, sku: sku, warehouse: wh, on_hand: 1, reserved: 0)

    post "/orders",
         params: {
           delivery_city: "Mumbai",
           idempotency_key: SecureRandom.uuid,
           lines: [{ sku_code: "WIDGET", quantity: 10 }]
         }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("insufficient inventory")
  end

  it "requires hosted checkout before marking an order paid" do
    user = User.create!(email: "pay@example.com", password: "password", password_confirmation: "password")
    login!(email: user.email, password: "password")

    sku = create(:sku, code: "WIDGET", name: "Widget", price_cents: 5000)
    wh = create(:warehouse, code: "WH-A", name: "Warehouse A", location: "Delhi")
    create(:stock_item, sku: sku, warehouse: wh, on_hand: 5, reserved: 0)

    post "/orders",
         params: {
           delivery_city: "Delhi",
           idempotency_key: SecureRandom.uuid,
           lines: [{ sku_code: "WIDGET", quantity: 1 }]
         }
    expect(response).to have_http_status(:found)
    location = response.headers.fetch("Location")
    pay_path = URI.parse(location).path
    expect(pay_path).to match(%r{\A/orders/\d+/pay\z})

    follow_redirect!
    expect(response).to have_http_status(:ok)

    order_id = pay_path.split("/").fetch(-2).to_i
    order = Order.find(order_id)
    expect(order.payment_pending?).to be(true)

    # Posting /pay should redirect to hosted checkout and not mark paid.
    post "/orders/#{order.id}/pay"
    expect(response).to have_http_status(:found)
    expect(URI.parse(response.headers.fetch("Location")).path).to eq("/orders/#{order.id}/checkout")
    expect(order.reload.payment_pending?).to be(true)

    # Hosted checkout "Pay" should redirect through callback and then mark paid.
    post "/orders/#{order.id}/checkout"
    expect(response).to have_http_status(:found)
    expect(URI.parse(response.headers.fetch("Location")).path).to include("/orders/#{order.id}/payment_callback")

    follow_redirect!
    expect(response).to have_http_status(:found) # callback redirects to order show
    follow_redirect!
    expect(response).to have_http_status(:ok)

    expect(order.reload.paid?).to be(true)
  end
end


