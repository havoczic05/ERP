class BankAccount < ApplicationRecord
  HUMAN_ATTRS = {
    "bank" => "Banco",
    "currency_label" => "Moneda",
    "account_number" => "Cuenta corriente",
    "interbank_number" => "Cuenta interbancaria",
    "position" => "Orden"
  }.freeze
  include SpanishAttributeNames

  belongs_to :company_settings

  validates :bank, presence: { message: "no puede estar en blanco" }
end
