class Client < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enum
  # ---------------------------------------------------------------------------
  enum :document_type, { ruc: "ruc", dni: "dni" }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  # Sales table does not exist yet. Declared now so the destroyable? guard can
  # use respond_to?(:sales) consistently; FK enforcement ships with the Sales module.
  has_many :sales, dependent: :restrict_with_error

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :full_name, presence: { message: "no puede estar en blanco" }
  validates :document_type, presence: { message: "no puede estar en blanco" }
  validates :document_number, presence: { message: "no puede estar en blanco" }
  validates :phone, presence: { message: "no puede estar en blanco" }

  # Conditional format validation based on document_type enum predicates.
  validates :document_number,
            format: { with: /\A\d{11}\z/, message: "debe tener exactamente 11 dígitos numéricos para RUC" },
            if: :ruc?

  validates :document_number,
            format: { with: /\A\d{8}\z/, message: "debe tener exactamente 8 dígitos numéricos para DNI" },
            if: :dni?

  # Model-level uniqueness scoped to active (non-discarded) records.
  # DB partial index (WHERE discarded_at IS NULL) provides race-condition safety.
  validates :document_number,
            uniqueness: {
              conditions: -> { where(discarded_at: nil) },
              message: "ya está registrado"
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
  # Destroy guard
  # ---------------------------------------------------------------------------
  # Returns false when the client has Sales, preventing hard or soft delete.
  # Uses a safe guard with respond_to? so this works before the Sales table exists.
  # When the Sales table is absent, sales.exists? would normally raise PG::UndefinedTable;
  # however, Rails only defines the :sales association method when has_many is declared.
  # We rescue ActiveRecord::StatementInvalid for the edge-case where the association is
  # present but the table has not been migrated yet in the test environment.
  def destroyable?
    return true unless respond_to?(:sales)

    begin
      !sales.exists?
    rescue ActiveRecord::StatementInvalid, NameError
      # Sales table or Sale class does not exist yet — treat as no sales present.
      # ActiveRecord::StatementInvalid: table missing (PG::UndefinedTable).
      # NameError: Sale constant not yet defined (model ships with Sales module).
      true
    end
  end
end
