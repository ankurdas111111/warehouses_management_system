module Inventory
  class SetOnHand
    def initialize(sku_code:, warehouse_code:, on_hand:)
      @sku_code = sku_code
      @warehouse_code = warehouse_code
      @on_hand = on_hand.to_i
    end

    def call
      raise ValidationError, "sku_code is required" if @sku_code.blank?
      raise ValidationError, "warehouse_code is required" if @warehouse_code.blank?
      raise ValidationError, "on_hand must be >= 0" if @on_hand.negative?

      sku = Sku.find_by!(code: @sku_code)
      warehouse = Warehouse.find_by!(code: @warehouse_code)

      StockItem.transaction do
        stock_item =
          StockItem.where(sku: sku, warehouse: warehouse).lock.first ||
            StockItem.create!(sku: sku, warehouse: warehouse, on_hand: 0, reserved: 0)

        stock_item.update!(on_hand: @on_hand)
        ActiveSupport::Notifications.instrument(
          "inventory.set_on_hand",
          sku_id: sku.id,
          warehouse_id: warehouse.id,
          on_hand: stock_item.on_hand,
          reserved: stock_item.reserved
        )
        stock_item
      end
    end
  end
end
