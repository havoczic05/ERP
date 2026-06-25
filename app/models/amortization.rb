class Amortization < ApplicationRecord
  HUMAN_ATTRS = {
    "amount_usd" => "Monto (USD)",
    "paid_at" => "Fecha de pago",
    "installment" => "Cuota"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :installment, optional: true

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :installment, presence: { message: "debe existir" }
  validates :amount_usd, numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  validates :paid_at, presence: { message: "no puede estar en blanco" }
end
