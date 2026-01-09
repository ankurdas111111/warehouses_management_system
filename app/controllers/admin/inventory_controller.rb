module Admin
  class InventoryController < BaseController
    def index
      @sku_code = params[:sku_code].to_s.strip.presence
      @warehouse_code = params[:warehouse_code].to_s.strip.presence
      @location = params[:location].to_s.strip.presence

      scope = StockItem.includes(:sku, :warehouse).order(:id)
      scope = scope.joins(:sku).where(skus: { code: @sku_code }) if @sku_code
      scope = scope.joins(:warehouse).where(warehouses: { code: @warehouse_code }) if @warehouse_code
      scope = scope.joins(:warehouse).where(warehouses: { location: @location }) if @location

      @stock_items = scope.to_a
    end
  end
end


