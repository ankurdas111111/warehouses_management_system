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

      @skus = Sku.order(:code)
      @warehouses = Warehouse.order(:code)
    end

    def destroy
      stock_item = StockItem.includes(:sku, :warehouse).find(params[:id])
      if stock_item.reserved.positive?
        return redirect_to admin_inventory_index_path, alert: "Cannot delete: reserved > 0 for #{stock_item.sku.code} @ #{stock_item.warehouse.code}"
      end

      AuditLog.record!(
        action: "admin.inventory.destroy",
        auditable: stock_item,
        metadata: { sku_code: stock_item.sku.code, warehouse_code: stock_item.warehouse.code }
      )
      stock_item.destroy!
      redirect_to admin_inventory_index_path, notice: "Deleted stock item"
    end

    def create_sku
      p = create_sku_params

      sku = nil
      Sku.transaction do
        inr = p[:price_inr].to_s.strip
        price_cents = (BigDecimal(inr) * 100).to_i
        sku = Sku.create!(code: p[:code], name: p[:name], price_cents: price_cents)

        stocks = normalize_stocks(p[:stocks])
        stocks.each do |s|
          wh = Warehouse.find_by!(code: s[:warehouse_code])
          StockItem.create!(sku: sku, warehouse: wh, on_hand: s[:on_hand], reserved: 0)
        end
      end

      AuditLog.record!(action: "admin.inventory.create_sku", auditable: sku, metadata: { code: sku.code })
      redirect_to admin_inventory_index_path, notice: "SKU created (#{sku.code})"
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Inventory::Error => e
      redirect_to admin_inventory_index_path, alert: e.message
    end

    private

    def create_sku_params
      params.require(:sku).permit(:code, :name, :price_inr, stocks: %i[warehouse_code on_hand]).to_h.deep_symbolize_keys
    end

    def normalize_stocks(stocks)
      rows = Array(stocks)
      rows = rows.select { |r| r.is_a?(Hash) && r[:warehouse_code].present? }

      rows.map do |r|
        on_hand = r[:on_hand].to_i
        raise Inventory::ValidationError, "on_hand must be >= 0" if on_hand.negative?

        { warehouse_code: r[:warehouse_code].to_s, on_hand: on_hand }
      end
      .uniq { |r| r[:warehouse_code] }
    end
  end
end
