class CompanySettingsController < ApplicationController
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
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            turbo_stream.replace("company_settings", partial: "company_settings/details",
                                                      locals: { company_settings: @company_settings }),
            turbo_stream.append("toasts", partial: "layouts/toast",
                                          locals: { kind: :notice, message: "Configuración actualizada." })
          ]
        end
        format.html { redirect_to company_settings_path, notice: "Configuración actualizada." }
      end
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
