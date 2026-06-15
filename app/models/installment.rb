class Installment < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enums (string-backed)
  # ---------------------------------------------------------------------------
  enum :status, { pendiente: 'pendiente', pagada: 'pagada', vencida: 'vencida', anulada: 'anulada' }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale
  has_many :amortizations

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :amount_usd, numericality: { greater_than: 0 }
  validates :balance_usd, numericality: { greater_than_or_equal_to: 0 }
  validates :due_date, presence: true
  validates :installment_number, presence: true, numericality: { greater_than: 0, only_integer: true }
end
