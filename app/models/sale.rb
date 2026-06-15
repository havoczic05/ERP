class Sale < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enums (string-backed)
  # ---------------------------------------------------------------------------
  enum :document_type, { cotizacion: 'cotizacion', venta: 'venta' }
  enum :status, { confirmada: 'confirmada', anulada: 'anulada' }
  enum :billing_status, { pending: 'pending', sent: 'sent', accepted: 'accepted', rejected: 'rejected' }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :client
  belongs_to :warehouse
  belongs_to :source_cotizacion, class_name: 'Sale', optional: true,
             foreign_key: :source_cotizacion_id
  has_many :sale_items, dependent: :destroy
  has_many :installments, dependent: :destroy
  has_one :credit_note

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :document_type, presence: true
  validates :status, presence: true
  validates :correlative, presence: true, uniqueness: true

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
