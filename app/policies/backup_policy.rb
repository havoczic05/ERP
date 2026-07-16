class BackupPolicy < ApplicationPolicy
  ADMIN_ROLE = "administrador"

  # Backup actions are admin-only (mirrors ImportPolicy).
  def new?    = admin?
  def create? = admin?
  def download? = admin?

  private

  def admin?
    user.present? && user.role == ADMIN_ROLE
  end
end
