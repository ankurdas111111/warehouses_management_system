# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

sku = Sku.find_or_create_by!(code: "WIDGET") { |s| s.name = "Widget" }

wh_a = Warehouse.find_or_create_by!(code: "WH-A") { |w| w.name = "Warehouse A"; w.location = "BLR" }
wh_b = Warehouse.find_or_create_by!(code: "WH-B") { |w| w.name = "Warehouse B"; w.location = "MUM" }

StockItem.find_or_create_by!(sku: sku, warehouse: wh_a) do |si|
  si.on_hand = 5
  si.reserved = 0
end

StockItem.find_or_create_by!(sku: sku, warehouse: wh_b) do |si|
  si.on_hand = 5
  si.reserved = 0
end
