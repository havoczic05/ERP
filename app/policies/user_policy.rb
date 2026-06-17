class UserPolicy < ApplicationPolicy
  # All user management actions are restricted to administrador only.
  def index?   = admin?
  def show?    = admin?
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin?
  def update?  = admin?
  def destroy? = admin?

  private

  def admin?
    user.present? && user.admin?
  end
end
