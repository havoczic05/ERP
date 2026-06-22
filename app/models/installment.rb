class Installment < ApplicationRecord
  HUMAN_ATTRS = {
    "amount_usd" => "Monto (USD)",
    "balance_usd" => "Saldo (USD)",
    "due_date" => "Fecha de vencimiento",
    "installment_number" => "Número de cuota",
    "status" => "Estado",
    "sale" => "Venta"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Enums (string-backed)
  # ---------------------------------------------------------------------------
  enum :status, { pendiente: "pendiente", pagada: "pagada", vencida: "vencida", anulada: "anulada" }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :sale, optional: true
  has_many :amortizations

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :outstanding, -> { where(status: "pendiente").order(:due_date) }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :sale, presence: { message: "debe existir" }
  validates :amount_usd, numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  validates :balance_usd, numericality: { greater_than_or_equal_to: 0, message: "debe ser mayor o igual a 0" }
  validates :due_date, presence: { message: "no puede estar en blanco" }
  validates :installment_number, presence: { message: "no puede estar en blanco" },
            numericality: { greater_than: 0, only_integer: true, message: "debe ser mayor que 0" }

  # ---------------------------------------------------------------------------
  # Computed helpers
  # ---------------------------------------------------------------------------
  def overdue?
    pendiente? && due_date < Date.current
  end
end
