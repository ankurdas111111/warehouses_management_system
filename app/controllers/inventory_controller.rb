class InventoryController < ApplicationController
  def index
    p = index_params

    scope = StockItem.includes(:sku, :warehouse).order(:id)
    scope = scope.joins(:sku).where(skus: { code: p[:sku_code] }) if p[:sku_code].present?
    scope = scope.joins(:warehouse).where(warehouses: { code: p[:warehouse_code] }) if p[:warehouse_code].present?
    scope = scope.joins(:warehouse).where(warehouses: { location: p[:location] }) if p[:location].present?

    render json: scope.map { |si| serialize_stock_item(si) }
  end

  private

  def serialize_stock_item(stock_item)
    {
      id: stock_item.id,
      sku_code: stock_item.sku.code,
      warehouse_code: stock_item.warehouse.code,
      warehouse_location: stock_item.warehouse.location,
      on_hand: stock_item.on_hand,
      reserved: stock_item.reserved,
      available: stock_item.available
    }
  end

  def index_params
    params.permit(:sku_code, :warehouse_code, :location).to_h.deep_symbolize_keys
  end
end
