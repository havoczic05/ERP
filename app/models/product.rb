class Product < ApplicationRecord
  HUMAN_ATTRS = {
    "name" => "Nombre",
    "sku" => "SKU",
    "brand" => "Marca",
    "stock" => "Stock",
    "base_price_usd" => "Precio base (USD)",
    "warehouse" => "Almacén"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :warehouse, optional: true
  has_many :sale_items

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :name, presence: { message: "no puede estar en blanco" }
  validates :sku, presence: { message: "no puede estar en blanco" }
  validates :brand, presence: { message: "no puede estar en blanco" }
  validates :stock, numericality: { greater_than_or_equal_to: 0, message: "debe ser mayor o igual a 0" }
  validates :base_price_usd, numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  validates :warehouse, presence: { message: "debe existir" }

  # Model-level uniqueness scoped to active (non-discarded) products.
  # DB partial index (WHERE discarded_at IS NULL) provides race-condition safety.
  validates :sku,
            uniqueness: {
              conditions: -> { where(discarded_at: nil) },
              message: "ya está en uso por un producto activo"
            }

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

  # ---------------------------------------------------------------------------
  # Destroy guard (RF-PM-4)
  # ---------------------------------------------------------------------------
  def destroyable?
    !sale_items.exists?
  end
end
