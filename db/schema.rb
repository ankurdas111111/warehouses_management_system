# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_17_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_identifier"
    t.string "actor_type", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "ip"
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.string "request_method"
    t.string "request_path"
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["request_id"], name: "index_audit_logs_on_request_id"
  end

  create_table "fulfillment_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fulfillment_id", null: false
    t.bigint "inventory_reservation_id", null: false
    t.integer "quantity", null: false
    t.bigint "sku_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fulfillment_id", "inventory_reservation_id"], name: "idx_fi_fulfillment_reservation_unique", unique: true
    t.index ["fulfillment_id"], name: "index_fulfillment_items_on_fulfillment_id"
    t.index ["inventory_reservation_id"], name: "index_fulfillment_items_on_inventory_reservation_id"
    t.index ["sku_id"], name: "index_fulfillment_items_on_sku_id"
    t.check_constraint "quantity > 0", name: "fulfillment_items_quantity_positive"
  end

  create_table "fulfillments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["order_id"], name: "index_fulfillments_on_order_id"
    t.index ["warehouse_id"], name: "index_fulfillments_on_warehouse_id"
  end

  create_table "inventory_reservations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "fulfilled_quantity", default: 0, null: false
    t.bigint "order_id", null: false
    t.integer "quantity", null: false
    t.bigint "sku_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["order_id", "sku_id", "warehouse_id"], name: "idx_reservations_order_sku_wh"
    t.index ["order_id"], name: "index_inventory_reservations_on_order_id"
    t.index ["sku_id"], name: "index_inventory_reservations_on_sku_id"
    t.index ["warehouse_id"], name: "index_inventory_reservations_on_warehouse_id"
    t.check_constraint "fulfilled_quantity <= quantity", name: "inventory_reservations_fulfilled_quantity_lte_quantity"
    t.check_constraint "fulfilled_quantity >= 0", name: "inventory_reservations_fulfilled_quantity_non_negative"
    t.check_constraint "quantity > 0", name: "inventory_reservations_quantity_positive"
  end

  create_table "order_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "fulfilled_quantity", default: 0, null: false
    t.bigint "order_id", null: false
    t.integer "quantity", null: false
    t.bigint "sku_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "sku_id"], name: "index_order_lines_on_order_id_and_sku_id", unique: true
    t.index ["order_id"], name: "index_order_lines_on_order_id"
    t.index ["sku_id"], name: "index_order_lines_on_sku_id"
    t.check_constraint "fulfilled_quantity <= quantity", name: "order_lines_fulfilled_quantity_lte_quantity"
    t.check_constraint "fulfilled_quantity >= 0", name: "order_lines_fulfilled_quantity_non_negative"
    t.check_constraint "quantity > 0", name: "order_lines_quantity_positive"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_email", null: false
    t.string "delivery_city"
    t.string "idempotency_key", null: false
    t.integer "payment_status", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["delivery_city"], name: "index_orders_on_delivery_city"
    t.index ["idempotency_key"], name: "index_orders_on_idempotency_key", unique: true
    t.index ["payment_status"], name: "index_orders_on_payment_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_paise", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "order_id"
    t.bigint "payable_id"
    t.string "payable_type"
    t.string "provider", null: false
    t.string "provider_order_id", null: false
    t.string "provider_payment_id"
    t.string "signature"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["payable_type", "payable_id"], name: "index_payments_on_payable"
    t.index ["provider", "provider_order_id"], name: "index_payments_on_provider_and_provider_order_id", unique: true
  end

  create_table "skus", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_skus_on_code", unique: true
    t.index ["price_cents"], name: "index_skus_on_price_cents"
  end

  create_table "stock_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "on_hand", default: 0, null: false
    t.integer "reserved", default: 0, null: false
    t.bigint "sku_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["sku_id", "warehouse_id"], name: "index_stock_items_on_sku_id_and_warehouse_id", unique: true
    t.index ["sku_id"], name: "index_stock_items_on_sku_id"
    t.index ["warehouse_id"], name: "index_stock_items_on_warehouse_id"
    t.check_constraint "on_hand >= 0", name: "stock_items_on_hand_non_negative"
    t.check_constraint "reserved <= on_hand", name: "stock_items_reserved_lte_on_hand"
    t.check_constraint "reserved >= 0", name: "stock_items_reserved_non_negative"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wallet_transactions", force: :cascade do |t|
    t.integer "amount_paise", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.integer "kind", default: 0, null: false
    t.bigint "order_id"
    t.bigint "payment_id"
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "wallet_id", null: false
    t.index ["idempotency_key"], name: "index_wallet_transactions_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["order_id"], name: "index_wallet_transactions_on_order_id"
    t.index ["payment_id"], name: "index_wallet_transactions_on_payment_id"
    t.index ["wallet_id"], name: "index_wallet_transactions_on_wallet_id"
  end

  create_table "wallets", force: :cascade do |t|
    t.integer "balance_paise", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_wallets_on_user_id", unique: true
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_warehouses_on_code", unique: true
    t.index ["location"], name: "index_warehouses_on_location"
  end

  add_foreign_key "fulfillment_items", "fulfillments"
  add_foreign_key "fulfillment_items", "inventory_reservations"
  add_foreign_key "fulfillment_items", "skus"
  add_foreign_key "fulfillments", "orders"
  add_foreign_key "fulfillments", "warehouses"
  add_foreign_key "inventory_reservations", "orders"
  add_foreign_key "inventory_reservations", "skus"
  add_foreign_key "inventory_reservations", "warehouses"
  add_foreign_key "order_lines", "orders"
  add_foreign_key "order_lines", "skus"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "orders"
  add_foreign_key "stock_items", "skus"
  add_foreign_key "stock_items", "warehouses"
  add_foreign_key "wallet_transactions", "orders"
  add_foreign_key "wallet_transactions", "payments"
  add_foreign_key "wallet_transactions", "wallets"
  add_foreign_key "wallets", "users"
end
