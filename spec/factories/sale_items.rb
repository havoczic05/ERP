FactoryBot.define do
  factory :sale_item do
    association :sale
    association :product
    quantity { 1 }
    unit_price_usd { 10.00 }
    line_total_usd { 10.00 }
  end
end
