class UsersController < ApplicationController
  before_action :set_user, only: %i[edit update destroy]

  def index
    authorize User
    @pagy, @users = pagy(:offset, User.order(:email))
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      redirect_to users_path, notice: "User was successfully created."
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
      flash.now[:alert] = "Cannot demote the last active administrator."
      render :edit, status: :unprocessable_content
      return
    end

    filtered = user_params_for_update
    if @user.update(filtered)
      redirect_to users_path, notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @user

    # Guard: cannot deactivate yourself
    if @user == current_user
      redirect_to users_path, alert: "You cannot deactivate your own account."
      return
    end

    # Guard: cannot deactivate the last active administrador
    if User.last_active_admin?(@user)
      redirect_to users_path, alert: "Cannot deactivate the last active administrator."
      return
    end

    @user.update!(active: false)
    redirect_to users_path, notice: "User was successfully deactivated."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :role, :password, :password_confirmation)
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
