class ImportsController < ApplicationController
  include CsvExport

  # ---------------------------------------------------------------------------
  # Products import
  # ---------------------------------------------------------------------------
  def new_products
    authorize :import, :new?
  end

  def create_products
    authorize :import, :create?

    result = run_import(Importers::ProductImporter)
    handle_result(result, :new_products, ProductsController::CSV_HEADERS)
  end

  def product_template
    authorize :import, :new?
    send_csv("plantilla-productos", ProductsController::CSV_HEADERS, [])
  end

  # ---------------------------------------------------------------------------
  # Clients import
  # ---------------------------------------------------------------------------
  def new_clients
    authorize :import, :new?
  end

  def create_clients
    authorize :import, :create?

    result = run_import(Importers::ClientImporter)
    handle_result(result, :new_clients, ClientsController::CSV_HEADERS)
  end

  def client_template
    authorize :import, :new?
    send_csv("plantilla-clientes", ClientsController::CSV_HEADERS, [])
  end

  private

  # Upload the file, call the importer, return a Result.
  def run_import(importer_class)
    uploaded = params[:file]

    unless uploaded.present?
      return Result.failure(nil, [ "Seleccione un archivo CSV (.csv) o Excel (.xlsx)." ])
    end

    importer_class.call(uploaded.path, content_type: uploaded.content_type)
  end

  # Render turbo-stream report on success; re-render form with error on failure.
  def handle_result(result, new_action, _headers)
    if result.success?
      @report = result.record
      toast_msg = build_toast(result.record)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("import_results", partial: "imports/report", locals: { report: @report }),
            turbo_stream.append("toasts", partial: "layouts/toast", locals: { kind: :notice, message: toast_msg })
          ]
        end
        format.html do
          # HTML fallback (rack_test, non-Turbo): re-render the form page with
          # @report available so the _form partial can render _report inline.
          render new_action
        end
      end
    else
      @error = result.errors.first
      render new_action, status: :unprocessable_content
    end
  end

  def build_toast(report)
    if report.error_count.zero?
      "#{report.created_count} creados correctamente."
    else
      "#{report.created_count} creados, #{report.error_count} con error."
    end
  end
end
