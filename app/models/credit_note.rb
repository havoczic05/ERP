class CreditNote < ApplicationRecord
  HUMAN_ATTRS = {
    "total_usd" => "Total (USD)",
    "issued_at" => "Fecha de emisión",
    "sale" => "Venta",
    "notes" => "Notas"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale, optional: true

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :sale, presence: { message: "debe existir" }
  validates :total_usd, numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  validates :issued_at, presence: { message: "no puede estar en blanco" }
end
