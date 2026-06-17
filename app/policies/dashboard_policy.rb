class DashboardPolicy < ApplicationPolicy
  ADMIN_ROLE = "administrador"

  # The admin analytics dashboard is visible to administrators only.
  def show? = admin?

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
