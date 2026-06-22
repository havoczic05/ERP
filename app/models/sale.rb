class Sale < ApplicationRecord
  HUMAN_ATTRS = {
    "document_type" => "Tipo de documento",
    "status" => "Estado",
    "correlative" => "Correlativo",
    "client" => "Cliente",
    "warehouse" => "Almacén",
    "source_cotizacion" => "Cotización de origen",
    "notes" => "Notas",
    "subtotal_usd" => "Subtotal (USD)",
    "tax_usd" => "Impuesto (USD)",
    "total_usd" => "Total (USD)"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Enums (string-backed)
  # ---------------------------------------------------------------------------
  enum :document_type, { cotizacion: "cotizacion", venta: "venta" }
  enum :status, { confirmada: "confirmada", anulada: "anulada" }
  enum :billing_status, { pending: "pending", sent: "sent", accepted: "accepted", rejected: "rejected" }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :client, optional: true
  belongs_to :warehouse, optional: true
  belongs_to :source_cotizacion, class_name: "Sale", optional: true,
             foreign_key: :source_cotizacion_id
  has_many :sale_items, dependent: :destroy
  has_many :installments, dependent: :destroy
  has_one :credit_note

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :document_type, presence: { message: "no puede estar en blanco" }
  validates :status, presence: { message: "no puede estar en blanco" }
  validates :correlative, presence: { message: "no puede estar en blanco" },
            uniqueness: { message: "ya está en uso" }
  validates :client, presence: { message: "debe existir" }
  validates :warehouse, presence: { message: "debe existir" }

  # ---------------------------------------------------------------------------
  # Scopes (no default_scope — explicit call required)
  # ---------------------------------------------------------------------------
  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  # ---------------------------------------------------------------------------
  # Soft-delete
  # ---------------------------------------------------------------------------
  def discard
    update!(discarded_at: Time.current)
  end

  def undiscard
    update!(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end
end
