FactoryBot.define do
  factory :installment do
    association :sale
    installment_number { 1 }
    amount_usd { 100.00 }
    balance_usd { 100.00 }
    due_date { 30.days.from_now }
    status { 'pendiente' }
  end
end
