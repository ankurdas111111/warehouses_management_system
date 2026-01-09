FactoryBot.define do
  factory :sku do
    sequence(:code) { |n| "SKU-#{n}" }
    name { "Test SKU" }
  end
end


