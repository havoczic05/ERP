FactoryBot.define do
  factory :client do
    sequence(:full_name) { |n| "Client #{n}" }
    phone { '999999999' }

    trait :ruc_client do
      document_type { 'ruc' }
      sequence(:document_number) { |n| format('20%09d', n) }
    end

    trait :dni_client do
      document_type { 'dni' }
      sequence(:document_number) { |n| format('%08d', n) }
    end
  end
end
