class ProductPolicy < ApplicationPolicy
  ALLOWED_ROLES = %w[administrador vendedor].freeze
  ADMIN_ROLE = "administrador"

  # Read + search: both roles (vendedores pick products when selling).
  def index?  = allowed?
  def show?   = allowed?
  def search? = allowed?

  # Creating / editing / deleting products is admin-only.
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin?
  def update?  = admin?
  def destroy? = admin?

  private

  def allowed?
    user.present? && user.role.in?(ALLOWED_ROLES)
  end

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
