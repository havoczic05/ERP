class SalesController < ApplicationController
  include CsvExport

  before_action :set_sale,        only: %i[show]
  before_action :set_kept_sale,   only: %i[annul convert_to_sale]

  # GET /sales(.csv)
  def index
    authorize Sale
    # Annulled sales soft-delete (discarded_at), but per spec RF3.1 they MUST remain
    # visible in the index for audit purposes — hence kept OR anulada.
    scope = filter_sales(Sale.kept.or(Sale.anulada).order(created_at: :desc))
    @subtotal = scope.sum(:total_usd) # subtotal of the FILTERED set (not the page)

    respond_to do |format|
      # ~15 rows so the pagination/footer fits on screen without much scrolling.
      format.html { @pagy, @sales = pagy(:offset, scope, limit: 15) }
      format.csv { send_csv("ventas", SALES_CSV_HEADERS, sales_csv_rows(scope)) }
    end
  end

  # GET /sales/new
  def new
    @sale = Sale.new
    authorize @sale
    @products = product_options
    @warehouses = Warehouse.order(:name)
  end

  # POST /sales
  def create
    @sale = Sale.new
    authorize @sale

    result = SaleCreationService.call(sale_creation_params)

    if result.success?
      redirect_to result.sale, notice: "Documento creado correctamente."
    else
      @sale = result.sale || Sale.new
      @errors = result.errors
      @products = product_options
      @warehouses = Warehouse.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sales/:id(.pdf)
  def show
    authorize @sale
    @amortizations = @sale.amortizations.includes(:installment).order(:paid_at)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = SalePdf.new(@sale, CompanySettings.instance)
        send_data pdf.render,
                  filename: "#{@sale.correlative}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  # POST /sales/:id/convert_to_sale
  def convert_to_sale
    authorize @sale

    conversion_params = {
      num_installments: params[:num_installments].to_i,
      interval_days:    params[:interval_days].to_i
    }
    conversion_params[:num_installments] = 1 if conversion_params[:num_installments] < 1
    conversion_params[:interval_days]    = 30 if conversion_params[:interval_days] <= 0

    result = SaleCreationService.convert(@sale, conversion_params)

    if result.success?
      redirect_to result.sale, notice: "Cotización convertida a venta correctamente."
    else
      flash[:alert] = result.errors.join("; ")
      redirect_to @sale
    end
  end

  # POST /sales/:id/annul
  def annul
    authorize @sale, :annul?

    result = SaleAnnulmentService.call(@sale, current_user)

    if result.success?
      redirect_to @sale, notice: "Venta anulada correctamente."
    else
      flash[:alert] = result.errors.join("; ")
      redirect_to @sale
    end
  end

  private

  # Apply the index filters: client name (q), document_type, status, and date
  # (a specific day via `on`, else a preset via `date_range`). Unknown values
  # are ignored, so a bad param never breaks the page.
  def filter_sales(scope)
    if params[:q].present?
      scope = scope.joins(:client).where("clients.full_name ILIKE ?", "%#{params[:q]}%")
    end
    scope = scope.where(document_type: params[:document_type]) if Sale.document_types.key?(params[:document_type])
    scope = scope.where(status: params[:status]) if Sale.statuses.key?(params[:status])

    range = DateRange.for_day(params[:on]) || DateRange.for(params[:date_range])
    scope = scope.where(created_at: range) if range
    scope
  end

  SALES_CSV_HEADERS = [ "Correlativo", "Fecha", "Tipo", "Cliente", "Total (USD)", "Estado" ].freeze

  def sales_csv_rows(scope)
    scope.includes(:client).map do |sale|
      [
        sale.correlative,
        helpers.format_date(sale.created_at),
        helpers.document_type_label(sale.document_type),
        sale.client.full_name,
        sale.total_usd,
        sale.status.humanize
      ]
    end
  end

  # Show allows viewing annulled (discarded) sales for audit purposes.
  def set_sale
    @sale = Sale.find(params[:id])
  end

  # Annul and convert_to_sale operate only on kept (non-discarded) sales.
  def set_kept_sale
    @sale = Sale.kept.find(params[:id])
  end

  def sale_creation_params
    raw = params.require(:sale).permit(
      :client_id, :warehouse_id, :document_type,
      :num_installments, :interval_days, :notes,
      items: %i[product_id product_query quantity unit_price_usd]
    )

    {
      client_id:        raw[:client_id],
      warehouse_id:     raw[:warehouse_id],
      document_type:    raw[:document_type],
      num_installments: raw[:num_installments].to_i,
      interval_days:    raw[:interval_days].to_i,
      notes:            raw[:notes],
      items:            Array(raw[:items]).map do |item|
        {
          product_id:     resolve_product_id(item),
          quantity:       item[:quantity].to_i,
          unit_price_usd: item[:unit_price_usd]
        }
      end
    }
  end

  # Resolve a line item to a product_id. Accepts an explicit product_id (used by
  # the API / request specs) or a "Name (SKU)" datalist label typed in the
  # new-sale form, resolved by the unique SKU, falling back to an exact name
  # match for free-typed input. Returns 0 when unresolved so SaleCreationService
  # reports a "product does not exist" failure (its existing contract).
  def resolve_product_id(item)
    return item[:product_id].to_i if item[:product_id].present?

    query = item[:product_query].to_s.strip
    return 0 if query.blank?

    sku = query[/\(([^)]+)\)\s*\z/, 1]
    product = sku ? Product.kept.find_by(sku: sku) : Product.kept.find_by(name: query)
    product&.id || 0
  end

  # Products for the new-sale datalist (name-based search). Ordered by name.
  def product_options
    Product.kept.order(:name)
  end
end
