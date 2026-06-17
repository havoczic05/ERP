class CompanySettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company_settings

  def show
    authorize @company_settings
  end

  def edit
    authorize @company_settings
  end

  def update
    authorize @company_settings

    if @company_settings.update(company_settings_params)
      redirect_to company_settings_path, notice: "Settings updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_company_settings
    @company_settings = CompanySettings.instance
  end

  def company_settings_params
    params.require(:company_settings).permit(:razon_social, :ruc, :direccion, :telefono, :logo)
  end
end
