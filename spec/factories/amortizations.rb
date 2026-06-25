FactoryBot.define do
  factory :amortization do
    association :installment
    amount_usd { 50.00 }
    paid_at { Time.current }
  end
end
