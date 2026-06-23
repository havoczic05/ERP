class ClientPolicy < ApplicationPolicy
  ALLOWED_ROLES = %w[administrador vendedor].freeze
  ADMIN_ROLE = "administrador"

  # Read + create: both roles (a vendedor can register a client to sell to).
  def index?  = allowed?
  def show?   = allowed?
  def new?    = allowed?
  def create? = allowed?
  def search? = allowed?

  # Modifying / archiving a client is admin-only.
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
