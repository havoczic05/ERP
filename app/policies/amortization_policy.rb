class AmortizationPolicy < ApplicationPolicy
  ALLOWED_ROLES = %w[administrador vendedor].freeze

  def index?   = allowed?
  def create?  = allowed?

  private

  def allowed?
    user.present? && user.role.in?(ALLOWED_ROLES)
  end
end
