class ClientsController < ApplicationController
  include CsvExport

  before_action :set_client, only: %i[show edit update destroy]

  CSV_HEADERS = [ "Nombre completo", "Tipo de documento", "Número de documento", "Teléfono",
                  "Dirección", "Distrito", "Provincia", "Departamento" ].freeze

  def index
    authorize Client
    scope = Client.kept.order(:full_name)
    scope = search_clients(scope, params[:q]) if params[:q].present?
    scope = scope.where(document_type: params[:document_type]) if Client.document_types.key?(params[:document_type])

    respond_to do |format|
      format.html { @pagy, @clients = pagy(:offset, scope, limit: 10) }
      format.csv { send_csv("clientes", CSV_HEADERS, clients_csv_rows(scope)) }
    end
  end

  def search
    authorize Client, :search?
    term = params[:q].to_s.strip
    scope = Client.kept
    @clients = term.present? ? search_clients(scope, term) : scope.none
    render partial: "clients/results"
  end

  def show
    authorize @client
  end

  def new
    @client = Client.new
    authorize @client
  end

  def create
    @client = Client.new(client_params)
    authorize @client

    if @client.save
      respond_to do |format|
        format.turbo_stream do
          streams = if params[:context] == "sale"
                      client_saved_for_sale_streams(@client)
          else
                      client_saved_streams(@client, "Cliente creado correctamente.", prepend: true)
          end
          render turbo_stream: streams
        end
        format.html { redirect_to @client, notice: "Cliente creado correctamente." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @client.errors.add(:document_number, "ya está registrado")
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @client
  end

  def update
    authorize @client

    if @client.update(client_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: client_saved_streams(@client, "Cliente actualizado correctamente.", prepend: false) }
        format.html { redirect_to @client, notice: "Cliente actualizado correctamente." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @client.errors.add(:document_number, "ya está registrado")
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize @client

    if @client.destroyable?
      @client.discard
      redirect_to clients_path, notice: "Cliente archivado correctamente."
    else
      redirect_to clients_path, alert: "No se puede eliminar este cliente porque tiene ventas asociadas."
    end
  end

  private

  def set_client
    @client = Client.kept.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:full_name, :document_type, :document_number, :phone,
                                   :direccion, :distrito, :provincia, :departamento)
  end

  # Turbo Stream set for a saved client: close the modal, refresh its table row
  # (prepend for new, replace for existing) and append a confirmation toast.
  def client_saved_streams(client, message, prepend:)
    row = if prepend
            turbo_stream.prepend("clients", partial: "clients/client", locals: { client: client })
    else
            turbo_stream.replace(client, partial: "clients/client", locals: { client: client })
    end

    [
      turbo_stream.update("modal", ""),
      row,
      turbo_stream.append("toasts", partial: "layouts/toast", locals: { kind: :notice, message: message })
    ]
  end

  # Turbo Stream set for a client created FROM the sale form: close the modal and
  # append the auto-select bridge (which selects the new client into the sale's
  # combobox in place, so the half-entered sale is preserved). No clients-table
  # row (that table isn't on the sale page).
  def client_saved_for_sale_streams(client)
    [
      turbo_stream.update("modal", ""),
      turbo_stream.append("sale-client-receiver", partial: "clients/sale_autoselect", locals: { client: client }),
      turbo_stream.append("toasts", partial: "layouts/toast",
                                    locals: { kind: :notice, message: "Cliente creado y seleccionado." })
    ]
  end

  def clients_csv_rows(scope)
    scope.map do |client|
      [
        client.full_name,
        client.document_type.upcase,
        client.document_number,
        client.phone,
        client.direccion,
        client.distrito,
        client.provincia,
        client.departamento
      ]
    end
  end

  def search_clients(scope, query)
    term = query.to_s.strip
    return scope if term.blank?

    scope.where(
      "document_number ILIKE :q OR full_name ILIKE :q",
      q: "%#{term}%"
    )
  end
end
