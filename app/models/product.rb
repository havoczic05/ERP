class Product < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :warehouse
  has_many :sale_items

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :name, presence: true
  validates :sku, presence: true
  validates :brand, presence: true
  validates :stock, numericality: { greater_than_or_equal_to: 0 }
  validates :base_price_usd, numericality: { greater_than: 0 }

  # Model-level uniqueness scoped to active (non-discarded) products.
  # DB partial index (WHERE discarded_at IS NULL) provides race-condition safety.
  validates :sku,
            uniqueness: {
              conditions: -> { where(discarded_at: nil) },
              message: 'is already taken by an active product'
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
end
