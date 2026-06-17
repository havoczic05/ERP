class WarehousePolicy < ApplicationPolicy
  ADMIN_ROLE  = "administrador"
  READER_ROLES = %w[administrador vendedor].freeze

  # Both roles can list and view warehouses.
  def index? = reader?
  def show?  = reader?

  # Only administrador can mutate warehouses.
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin?
  def update?  = admin?
  def destroy? = admin?

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end

  def reader?
    user.present? && user.role.in?(READER_ROLES)
  end
end
