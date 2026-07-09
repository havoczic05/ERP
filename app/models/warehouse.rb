class Warehouse < ApplicationRecord
  HUMAN_ATTRS = {
    "name" => "Nombre",
    "location" => "Ubicación"
  }.freeze
  include SpanishAttributeNames

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  has_many :products
  has_many :sales

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :name, presence: { message: "no puede estar en blanco" }

  # ---------------------------------------------------------------------------
  # Destroy guard
  # ---------------------------------------------------------------------------
  # Returns false when the warehouse has associated products or sales, or is
  # the configured default warehouse, preventing hard delete. Uses EXISTS
  # queries (no N+1 risk).
  def destroyable?
    !products.exists? && !sales.exists? && !default_for_company?
  end

  # True when this warehouse is the currently configured default (RF-DW-5).
  def default_for_company?
    CompanySettings.instance.default_warehouse_id == id
  end
end
