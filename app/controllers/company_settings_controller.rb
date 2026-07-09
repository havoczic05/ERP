class CompanySettingsController < ApplicationController
  before_action :set_company_settings
  before_action :set_warehouses, only: %i[show update]

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
                                                      locals: { company_settings: @company_settings, warehouses: @warehouses }),
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

  # Used by the hub's "Almacén predeterminado" select (RF-DW-2).
  def set_warehouses
    @warehouses = Warehouse.order(:name)
  end

  def company_settings_params
    params.require(:company_settings).permit(
      :razon_social, :ruc, :direccion, :telefono, :logo, :subtitulo, :default_warehouse_id,
      bank_accounts_attributes: [ :id, :bank, :currency_label, :account_number, :interbank_number, :position, :_destroy ]
    )
  end
end
