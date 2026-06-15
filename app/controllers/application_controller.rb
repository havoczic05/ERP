class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Provides a current_user seam for Pundit and specs.
  # In test environment, specs may set @current_user directly via controller.current_user = user.
  # In non-test environments, this reads from the session (full auth deferred to a separate change).
  if Rails.env.test?
    attr_writer :current_user
  end

  def current_user
    @current_user ||= session[:user_id] && User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  private

  def user_not_authorized
    head :forbidden
  end
end
