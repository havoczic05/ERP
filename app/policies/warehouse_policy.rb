class WarehousePolicy < ApplicationPolicy
  ADMIN_ROLE = "administrador"

  # Warehouses are owner-only configuration: every action (incl. read) is
  # admin-only. The warehouse selects in product/sale forms load data directly
  # (Warehouse.order(:name)), not through this policy, so they are unaffected.
  def index?   = admin?
  def show?    = admin?
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin?
  def update?  = admin?
  def destroy? = admin?

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
