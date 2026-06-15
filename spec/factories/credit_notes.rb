FactoryBot.define do
  factory :credit_note do
    association :sale
    total_usd { 100.00 }
    issued_at { Time.current }
    notes { nil }
  end
end
