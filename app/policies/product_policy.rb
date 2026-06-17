class ProductPolicy < ApplicationPolicy
  ALLOWED_ROLES = %w[administrador vendedor].freeze

  def index?   = allowed?
  def show?    = allowed?
  def new?     = allowed?
  def create?  = allowed?
  def edit?    = allowed?
  def update?  = allowed?
  def destroy? = allowed?
  def search?  = allowed?

  private

  def allowed?
    user.present? && user.role.in?(ALLOWED_ROLES)
  end
end
