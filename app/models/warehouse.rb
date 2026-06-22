class Warehouse < ApplicationRecord
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
  # Returns false when the warehouse has associated products or sales,
  # preventing hard delete. Uses EXISTS queries (no N+1 risk).
  def destroyable?
    !products.exists? && !sales.exists?
  end
end
