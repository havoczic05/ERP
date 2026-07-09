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
  # Default warehouse (RF-DW-1) — preselected on new sales/products, nullified
  # by the DB FK if the warehouse is ever removed some other way.
  # ---------------------------------------------------------------------------
  belongs_to :default_warehouse, class_name: "Warehouse", optional: true

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :razon_social, presence: { message: "no puede estar en blanco" }
  validates :ruc,
            presence: { message: "no puede estar en blanco" },
            format: { with: /\A\d{11}\z/, message: "debe tener exactamente 11 dígitos numéricos" }
  validate :default_warehouse_must_exist

  # ---------------------------------------------------------------------------
  # Singleton accessor
  # Uses first_or_initialize so it NEVER raises on an empty DB (unlike
  # first_or_create! which would fail the presence validations).
  # ---------------------------------------------------------------------------
  def self.instance = first_or_initialize

  private

  # Guards against ActiveRecord::InvalidForeignKey (a DB-level 500) when the
  # default_warehouse_id points at a warehouse deleted between page load and
  # submit, or a crafted request. nil (clearing the default) stays valid.
  def default_warehouse_must_exist
    return if default_warehouse_id.blank?

    errors.add(:default_warehouse_id, "no es un almacén válido") unless Warehouse.exists?(default_warehouse_id)
  end
end
