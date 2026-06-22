class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!

  def current_user
    @current_user ||= session[:user_id] && User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  private

  # Authentication gate: nil current_user -> redirect to login.
  # Distinct from authz (Pundit NotAuthorizedError -> head :forbidden).
  def authenticate_user!
    redirect_to login_path, alert: "Inicie sesión para continuar." unless current_user
  end

  def user_not_authorized
    head :forbidden
  end
end
