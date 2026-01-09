FactoryBot.define do
  factory :stock_item do
    sku
    warehouse
    on_hand { 0 }
    reserved { 0 }
  end
end


