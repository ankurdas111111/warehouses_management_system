module Inventory
  class Adjust
    def initialize(sku_code:, warehouse_code:, delta:)
      @sku_code = sku_code
      @warehouse_code = warehouse_code
      @delta = delta.to_i
    end

    def call
      raise ValidationError, "sku_code is required" if @sku_code.blank?
      raise ValidationError, "warehouse_code is required" if @warehouse_code.blank?
      raise ValidationError, "delta must be non-zero" if @delta.zero?

      sku = Sku.find_by!(code: @sku_code)
      warehouse = Warehouse.find_by!(code: @warehouse_code)

      StockItem.transaction do
        stock_item =
          StockItem.where(sku: sku, warehouse: warehouse).lock.first ||
            StockItem.create!(sku: sku, warehouse: warehouse, on_hand: 0, reserved: 0)

        stock_item.update!(on_hand: stock_item.on_hand + @delta)
        ActiveSupport::Notifications.instrument(
          "inventory.adjust",
          sku_id: sku.id,
          warehouse_id: warehouse.id,
          delta: @delta,
          on_hand: stock_item.on_hand,
          reserved: stock_item.reserved
        )
        stock_item
      end
    end
  end
end


