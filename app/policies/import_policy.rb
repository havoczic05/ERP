class ImportPolicy < ApplicationPolicy
  ADMIN_ROLE = "administrador"

  # Import actions are admin-only (mirrors CompanySettingsPolicy).
  def new?    = admin?
  def create? = admin?

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
