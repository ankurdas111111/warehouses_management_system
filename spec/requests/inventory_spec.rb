require "rails_helper"

RSpec.describe "Inventory API", type: :request do
  it "lists stock items with available" do
    sku = create(:sku, code: "WIDGET", name: "Widget")
    wh = create(:warehouse, code: "WH-A", name: "Warehouse A", location: "BLR")
    create(:stock_item, sku: sku, warehouse: wh, on_hand: 5, reserved: 2)

    get "/api/inventory"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.length).to eq(1)
    expect(body.first["sku_code"]).to eq("WIDGET")
    expect(body.first["warehouse_code"]).to eq("WH-A")
    expect(body.first["warehouse_location"]).to eq("BLR")
    expect(body.first["on_hand"]).to eq(5)
    expect(body.first["reserved"]).to eq(2)
    expect(body.first["available"]).to eq(3)
  end
end


