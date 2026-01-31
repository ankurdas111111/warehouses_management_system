require "csv"

module Admin
  class ReportsController < BaseController
    def index
      @from = params[:from].presence
      @to = params[:to].presence
      @status = params[:status].presence
      @location = params[:location].presence
      @sku_code = params[:sku_code].presence
      @warehouse_code = params[:warehouse_code].presence

      @sku_codes = Sku.order(:code).pluck(:code)
      @warehouse_codes = Warehouse.order(:code).pluck(:code)
    end

    def orders
      from = parse_time(params[:from], beginning: true)
      to = parse_time(params[:to], end_of_day: true)
      status = params[:status].presence
      ActiveSupport::Notifications.instrument(
        "reports.orders.request",
        from: params[:from].presence,
        to: params[:to].presence,
        status: status
      )
      AuditLog.record!(
        action: "admin.reports.orders",
        metadata: { from: params[:from].presence, to: params[:to].presence, status: status }
      )

      scope = Order.all
      scope = scope.where("orders.created_at >= ?", from) if from
      scope = scope.where("orders.created_at <= ?", to) if to
      scope = scope.where(status: Order.statuses.fetch(status)) if status && Order.statuses.key?(status)

      orders =
        scope
          .order(created_at: :desc)
          .includes(:fulfillments, order_lines: :sku, inventory_reservations: %i[sku warehouse])

      filename = "orders-report-#{Time.current.strftime("%Y%m%d-%H%M%S")}.csv"

      csv = CSV.generate(headers: true) do |out|
        out << [
          "order_id",
          "created_at",
          "first_fulfilled_at",
          "last_fulfilled_at",
          "status",
          "customer_email",
          "user_id",
          "delivery_city",
          "idempotency_key",
          "payment_status",
          "order_total_paise",
          "order_total_inr",
          "ordered_qty_total",
          "fulfilled_qty_total",
          "reserved_qty_total",
          "reserved_fulfilled_qty_total",
          "reservation_count",
          "warehouse_count_allocated",
          "fulfillment_count"
        ]

        orders.each do |o|
          ordered_qty = o.order_lines.sum(&:quantity)
          fulfilled_qty = o.order_lines.sum(&:fulfilled_quantity)
          reserved_qty = o.inventory_reservations.sum(&:quantity)
          reserved_fulfilled_qty = o.inventory_reservations.sum(&:fulfilled_quantity)
          wh_count = o.inventory_reservations.map(&:warehouse_id).uniq.size
          first_fulfilled_at = o.first_fulfilled_at&.iso8601
          last_fulfilled_at = o.last_fulfilled_at&.iso8601
          total_paise = o.order_lines.sum { |l| l.quantity.to_i * l.sku.price_cents.to_i }
          total_inr = format("%.2f", total_paise.to_i / 100.0)

          out << [
            o.id,
            o.created_at&.iso8601,
            first_fulfilled_at,
            last_fulfilled_at,
            o.status,
            o.customer_email,
            o.user_id,
            o.delivery_city,
            o.idempotency_key,
            o.payment_status,
            total_paise,
            total_inr,
            ordered_qty,
            fulfilled_qty,
            reserved_qty,
            reserved_fulfilled_qty,
            o.inventory_reservations.size,
            wh_count,
            o.fulfillments.size
          ]
        end
      end

      ActiveSupport::Notifications.instrument(
        "reports.orders.generated",
        from: params[:from].presence,
        to: params[:to].presence,
        status: status,
        row_count: orders.size,
        filename: filename
      )
      send_data csv, filename: filename, type: "text/csv"
    end

    def inventory
      location = params[:location].presence
      sku_code = params[:sku_code].presence
      warehouse_code = params[:warehouse_code].presence
      ActiveSupport::Notifications.instrument(
        "reports.inventory.request",
        location: location,
        sku_code: sku_code,
        warehouse_code: warehouse_code
      )
      AuditLog.record!(
        action: "admin.reports.inventory",
        metadata: { location: location, sku_code: sku_code, warehouse_code: warehouse_code }
      )

      items =
        StockItem
          .includes(:sku, :warehouse)
          .joins(:sku, :warehouse)
          .order("skus.code ASC, warehouses.code ASC")

      items = items.where("warehouses.location = ?", location) if location
      items = items.where("skus.code = ?", sku_code) if sku_code
      items = items.where("warehouses.code = ?", warehouse_code) if warehouse_code

      filename = "inventory-snapshot-#{Time.current.strftime("%Y%m%d-%H%M%S")}.csv"

      csv = CSV.generate(headers: true) do |out|
        out << [
          "as_of",
          "sku_code",
          "sku_name",
          "sku_price_paise",
          "sku_price_inr",
          "warehouse_code",
          "warehouse_name",
          "warehouse_location",
          "on_hand",
          "reserved",
          "available"
        ]

        as_of = Time.current.iso8601
        items.each do |si|
          out << [
            as_of,
            si.sku.code,
            si.sku.name,
            si.sku.price_cents,
            format("%.2f", si.sku.price_cents.to_i / 100.0),
            si.warehouse.code,
            si.warehouse.name,
            si.warehouse.location,
            si.on_hand,
            si.reserved,
            si.available
          ]
        end
      end

      ActiveSupport::Notifications.instrument(
        "reports.inventory.generated",
        location: location,
        sku_code: sku_code,
        warehouse_code: warehouse_code,
        row_count: items.size,
        filename: filename
      )
      send_data csv, filename: filename, type: "text/csv"
    end

    private

    def parse_time(s, beginning: false, end_of_day: false)
      return nil if s.blank?

      t = Time.zone.parse(s.to_s)
      return nil unless t

      return t.beginning_of_day if beginning
      return t.end_of_day if end_of_day
      t
    end
  end
end
