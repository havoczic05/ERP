class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create]

  def new
    # Render login form
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.active? && user.authenticate(params[:password])
      reset_session # session-fixation protection
      session[:user_id] = user.id
      redirect_to root_path, notice: "Bienvenido de nuevo."
    else
      flash.now[:alert] = "Correo o contraseña inválidos"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Sesión cerrada."
  end
end
