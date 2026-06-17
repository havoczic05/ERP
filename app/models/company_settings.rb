class CompanySettings < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Attachments
  # ---------------------------------------------------------------------------
  has_one_attached :logo

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :razon_social, presence: true
  validates :ruc,
            presence: true,
            format: { with: /\A\d{11}\z/, message: "must be exactly 11 numeric digits" }

  # ---------------------------------------------------------------------------
  # Singleton accessor
  # Uses first_or_initialize so it NEVER raises on an empty DB (unlike
  # first_or_create! which would fail the presence validations).
  # ---------------------------------------------------------------------------
  def self.instance = first_or_initialize
end
