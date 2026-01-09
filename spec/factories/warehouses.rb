FactoryBot.define do
  factory :warehouse do
    sequence(:code) { |n| "WH-#{n}" }
    name { "Test Warehouse" }
    location { "BLR" }
  end
end


