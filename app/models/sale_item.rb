class SaleItem < ApplicationRecord
  HUMAN_ATTRS = {
    "quantity" => "Cantidad",
    "unit_price_usd" => "Precio unitario (USD)",
    "line_total_usd" => "Total de línea (USD)",
    "sale" => "Venta",
    "product" => "Producto"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale, optional: true
  belongs_to :product, optional: true

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :sale, presence: { message: "debe existir" }
  validates :product, presence: { message: "debe existir" }
  validates :quantity, numericality: { greater_than: 0, only_integer: true, message: "debe ser mayor que 0" }
  validates :unit_price_usd, numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  validates :line_total_usd, numericality: { greater_than_or_equal_to: 0, message: "debe ser mayor o igual a 0" }
end
