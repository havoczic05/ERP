class CompanySettings < ApplicationRecord
  HUMAN_ATTRS = {
    "razon_social" => "Razón social",
    "ruc" => "RUC",
    "direccion" => "Dirección",
    "telefono" => "Teléfono",
    "logo" => "Logo"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Attachments
  # ---------------------------------------------------------------------------
  has_one_attached :logo

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
