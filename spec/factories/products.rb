FactoryBot.define do
  factory :product do
    association :warehouse
    sequence(:sku) { |n| format('SKU-%04d', n) }
    sequence(:name) { |n| "Product #{n}" }
    brand { 'Generic Brand' }
    stock { 100 }
    base_price_usd { 10.00 }
    discarded_at { nil }
  end
end
