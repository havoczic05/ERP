FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    role { 'administrador' }

    trait :administrador do
      role { 'administrador' }
    end

    trait :vendedor do
      role { 'vendedor' }
    end
  end
end
