class SaleItem < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale
  belongs_to :product

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price_usd, numericality: { greater_than: 0 }
  validates :line_total_usd, numericality: { greater_than_or_equal_to: 0 }
end
