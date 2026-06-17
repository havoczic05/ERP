FactoryBot.define do
  factory :sale do
    association :client, factory: [ :client, :ruc_client ]
    association :warehouse
    document_type { 'cotizacion' }
    status { 'confirmada' }
    sequence(:correlative) { |n| format('COT-%05d', n) }
    subtotal_usd { 50.00 }
    tax_usd { 0.00 }
    total_usd { 50.00 }
    billing_status { 'pending' }
    billing_response_metadata { {} }
    discarded_at { nil }

    trait :venta do
      document_type { 'venta' }
      sequence(:correlative) { |n| format('VTA-%05d', n) }
    end

    trait :anulada do
      status { 'anulada' }
      discarded_at { Time.current }
    end

    trait :with_items do
      after(:create) do |sale|
        create(:sale_item, sale: sale)
      end
    end
  end
end
