class SalesController < ApplicationController
  include CsvExport

  before_action :set_sale,        only: %i[show]
  before_action :set_kept_sale,   only: %i[annul convert convert_to_sale]

  # GET /sales(.csv)
  def index
    authorize Sale
    # Annulled sales soft-delete (discarded_at), but per spec RF3.1 they MUST remain
    # visible in the index for audit purposes — hence kept OR anulada.
    # Sort by creation date; direction toggled from the "Fecha" header (default desc).
    dir   = params[:dir] == "asc" ? :asc : :desc
    scope = filter_sales(Sale.kept.or(Sale.anulada).order(created_at: dir))
    @subtotal = scope.sum(:total_usd) # subtotal of the FILTERED set (not the page)

    respond_to do |format|
      # 10 rows so the pagination/footer fits on screen without much scrolling.
      format.html { @pagy, @sales = pagy(:offset, scope, limit: 10) }
      format.csv { send_csv("ventas", SALES_CSV_HEADERS, sales_csv_rows(scope)) }
    end
  end

  # GET /sales/filters
  # Renders the mobile/tablet filter modal into the persistent turbo-frame#modal.
  def filters
    authorize Sale, :index?
    render partial: "shared/filter_modal", layout: false, locals: { resource: "sale", q: params[:q] }
  end

  # GET /sales/new
  def new
    @sale = Sale.new(document_type: "venta")
    authorize @sale
    @payment_method = "contado"
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
      all_errors = Array(result.errors)
      all_errors += Array(@sale.errors.full_messages) unless @sale.errors.empty?
      flash.now[:alert] = all_errors.uniq.join("; ")
      @payment_method = params[:payment_method] || "contado"
      @products = product_options
      @warehouses = Warehouse.order(:name)
      @line_items = line_items_from_params.presence || [ {} ]
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sales/:id(.pdf)
  def show
    authorize @sale

    respond_to do |format|
      format.html
      format.pdf do
        show_installments = params[:cuotas] == "true"
        suffix = show_installments ? "-cuotas" : ""
        pdf = SalePdf.new(@sale, CompanySettings.instance, show_installments: show_installments)
        send_data pdf.render,
                  filename: "#{@sale.correlative}#{suffix}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  # GET /sales/:id/convert
  # Renders the editable convert form preloaded from the cotizacion. The user
  # edits items and picks the payment plan before submitting to convert_to_sale.
  def convert
    authorize @sale, :convert_to_sale?

    reason = conversion_block_reason(@sale)
    return redirect_to(@sale, alert: reason) if reason

    @payment_method = "contado"
    load_convert_form
    render :convert
  end

  # POST /sales/:id/convert_to_sale
  # Builds a brand-new venta from the submitted (editable) form data, linked to
  # the source cotizacion. The already-converted guard lives in the service; the
  # controller pre-checks it to surface a Spanish message on the form.
  def convert_to_sale
    authorize @sale, :convert_to_sale?

    reason = conversion_block_reason(@sale)
    if reason
      flash.now[:alert] = reason
      return render_convert_form
    end

    params_for_venta = sale_creation_params.merge(
      document_type:        "venta",
      source_cotizacion_id: @sale.id
    )
    result = SaleCreationService.call(params_for_venta)

    if result.success?
      redirect_to result.sale, notice: "Cotización convertida a venta correctamente."
    else
      all_errors = Array(result.errors)
      all_errors += Array(result.sale.errors.full_messages) if result.sale&.errors&.any?
      flash.now[:alert] = all_errors.uniq.join("; ")
      @line_items = line_items_from_params
      render_convert_form
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

  # Apply the index filters: search (q) matches client name OR sale correlative,
  # plus document_type, status, and date (a specific day via `on`, else a preset
  # via `date_range`). Unknown values are ignored, so a bad param never breaks the page.
  def filter_sales(scope)
    if params[:q].present?
      scope = scope.joins(:client)
                   .where("clients.full_name ILIKE :q OR sales.correlative ILIKE :q",
                          q: "%#{params[:q]}%")
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

  # Annul and convert operate only on kept (non-discarded) sales.
  def set_kept_sale
    @sale = Sale.kept.find(params[:id])
  end

  # Shared setup for the convert form (GET and POST-failure re-render).
  def load_convert_form
    @products   = product_options
    @warehouses = Warehouse.order(:name)
  end

  def render_convert_form
    load_convert_form
    @payment_method = params[:payment_method] || "contado"
    render :convert, status: :unprocessable_entity
  end

  # Reason a cotizacion cannot be converted, or nil when it can. Keeps the GET
  # form from opening on a document that is already a venta or already has a
  # live (kept) venta. The service enforces the same guard on submit.
  def conversion_block_reason(sale)
    return "Este documento ya es una venta." if sale.venta?

    if Sale.kept.where(source_cotizacion_id: sale.id).exists?
      return "Esta cotización ya fue convertida a una venta."
    end

    nil
  end

  def sale_creation_params
    raw = params.require(:sale).permit(
      :client_id, :warehouse_id, :document_type,
      :num_installments, :interval_days, :notes,
      items: %i[product_id product_query quantity unit_price_usd],
      installments: %i[due_date amount_usd]
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
      end,
      # Editable installment plan (only submitted in Cuotas mode). Fully blank
      # rows are dropped here so a stray empty row never forces a rejection.
      installments:     Array(raw[:installments]).filter_map do |installment|
        due_date = installment[:due_date].to_s.strip
        amount   = installment[:amount_usd].to_s.strip
        next if due_date.blank? && amount.blank?

        { due_date: due_date, amount_usd: amount }
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

  # Rebuild @line_items from params[:sale][:items] on validation failure so the
  # re-rendered form preserves every row the user entered (product_query, qty,
  # unit_price) instead of wiping them with a hardcoded empty row.
  def line_items_from_params
    Array(params.dig(:sale, :items))
      .select { |item| item.respond_to?(:to_h) }
      .map do |item|
        pid     = item[:product_id].presence
        product = pid ? Product.kept.find_by(id: pid) : nil
        {
          product_id:    pid,
          product_query: product ? "#{product.name} (#{product.sku})" : item[:product_query],
          quantity:      item[:quantity],
          unit_price:    item[:unit_price_usd]
        }
      end
  end
end
