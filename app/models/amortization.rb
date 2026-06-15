class Amortization < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :installment

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :amount_usd, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
end
