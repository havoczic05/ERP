class CreditNote < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :total_usd, numericality: { greater_than: 0 }
  validates :issued_at, presence: true
end
