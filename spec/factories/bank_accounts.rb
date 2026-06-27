FactoryBot.define do
  factory :bank_account do
    association :company_settings
    bank             { "BCP" }
    currency_label   { "Dólares" }
    account_number   { "193-9852295-1-39" }
    interbank_number { "002-193-009852295139-15" }
    position         { 0 }
  end
end
