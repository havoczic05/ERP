class CompanySettingsPolicy < ApplicationPolicy
  ADMIN_ROLE = "administrador"

  # Only administrators can view or manage company settings.
  def show?   = admin?
  def edit?   = admin?
  def update? = admin?

  # No index, new, create, or destroy routes exist for this singleton resource.

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
