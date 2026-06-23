class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]

  def index
    authorize User
    @pagy, @users = pagy(:offset, User.order(:email))
  end

  def show
    authorize @user
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: user_saved_streams(@user, "Usuario creado correctamente.", prepend: true) }
        format.html { redirect_to users_path, notice: "Usuario creado correctamente." }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    # Guard: cannot demote the last active administrador
    if demoting_last_active_admin?
      flash.now[:alert] = "No se puede degradar al último administrador activo."
      render :edit, status: :unprocessable_content
      return
    end

    filtered = user_params_for_update
    if @user.update(filtered)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: user_saved_streams(@user, "Usuario actualizado correctamente.", prepend: false) }
        format.html { redirect_to users_path, notice: "Usuario actualizado correctamente." }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @user

    # Guard: cannot deactivate yourself
    if @user == current_user
      redirect_to users_path, alert: "No puede desactivar su propia cuenta."
      return
    end

    # Guard: cannot deactivate the last active administrador
    if User.last_active_admin?(@user)
      redirect_to users_path, alert: "No se puede desactivar al último administrador activo."
      return
    end

    @user.update!(active: false)
    redirect_to users_path, notice: "Usuario desactivado correctamente."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :role, :password, :password_confirmation)
  end

  # Turbo Stream set for a saved user: close the modal, refresh its table row
  # (prepend for new, replace for existing) and append a confirmation toast.
  def user_saved_streams(user, message, prepend:)
    row = if prepend
            turbo_stream.prepend("users", partial: "users/user", locals: { user: user })
    else
            turbo_stream.replace(user, partial: "users/user", locals: { user: user })
    end

    [
      turbo_stream.update("modal", ""),
      row,
      turbo_stream.append("toasts", partial: "layouts/toast", locals: { kind: :notice, message: message })
    ]
  end

  # For updates: strip blank password/confirmation so the existing digest is preserved.
  def user_params_for_update
    p = user_params
    if p[:password].blank?
      p.delete(:password)
      p.delete(:password_confirmation)
    end
    p
  end

  # Returns true when the target user is currently an administrador, would be
  # changed to a non-admin role, AND is the last active administrador.
  def demoting_last_active_admin?
    incoming_role = params.dig(:user, :role)
    return false if incoming_role.blank?
    return false if incoming_role == "administrador"
    return false unless @user.admin?

    User.last_active_admin?(@user)
  end
end
