class SessionsController < ApplicationController
  # Guard does not exist yet (added in Slice 3). This forward-compatible skip
  # ensures the action remains when the before_action is wired up in the next slice.
  # skip_before_action :authenticate_user!, only: %i[new create]

  def new
    # Render login form
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.active? && user.authenticate(params[:password])
      reset_session # session-fixation protection
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "You have been signed out."
  end
end
