class CompanySettings < ApplicationRecord
  HUMAN_ATTRS = {
    "razon_social" => "Razón social",
    "ruc" => "RUC",
    "direccion" => "Dirección",
    "telefono" => "Teléfono",
    "subtitulo" => "Subtítulo",
    "logo" => "Logo"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Attachments
  # ---------------------------------------------------------------------------
  has_one_attached :logo

  # ---------------------------------------------------------------------------
  # Associations — bank accounts shown in the PDF footers (BCP, etc.). Dynamic
  # so the user can add/remove accounts from the settings form.
  # ---------------------------------------------------------------------------
  has_many :bank_accounts, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :company_settings
  accepts_nested_attributes_for :bank_accounts, allow_destroy: true,
                                                reject_if: ->(attributes) { attributes["bank"].blank? }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :razon_social, presence: { message: "no puede estar en blanco" }
  validates :ruc,
            presence: { message: "no puede estar en blanco" },
            format: { with: /\A\d{11}\z/, message: "debe tener exactamente 11 dígitos numéricos" }

  # ---------------------------------------------------------------------------
  # Singleton accessor
  # Uses first_or_initialize so it NEVER raises on an empty DB (unlike
  # first_or_create! which would fail the presence validations).
  # ---------------------------------------------------------------------------
  def self.instance = first_or_initialize
end
