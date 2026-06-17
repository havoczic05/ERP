class SalePolicy < ApplicationPolicy
  ALLOWED_ROLES = %w[administrador vendedor].freeze

  def index?           = allowed?
  def show?            = allowed?
  def new?             = allowed?
  def create?          = allowed?
  def convert_to_sale? = allowed?

  # Annulment is restricted to administrators only.
  def annul?
    user.present? && user.role == "administrador"
  end

  private

  def allowed?
    user.present? && user.role.in?(ALLOWED_ROLES)
  end
end
