class SalesController < ApplicationController
  before_action :set_sale,        only: %i[show]
  before_action :set_kept_sale,   only: %i[annul convert_to_sale]

  # GET /sales
  def index
    authorize Sale
    # Annulled sales soft-delete (discarded_at), but per spec RF3.1 they MUST remain
    # visible in the index for audit purposes — hence kept OR anulada.
    scope = Sale.kept.or(Sale.anulada).order(created_at: :desc)
    @pagy, @sales = pagy(:offset, scope)
  end

  # GET /sales/new
  def new
    @sale = Sale.new
    authorize @sale
    @products = product_options
  end

  # POST /sales
  def create
    @sale = Sale.new
    authorize @sale

    result = SaleCreationService.call(sale_creation_params)

    if result.success?
      redirect_to result.sale, notice: "Document was successfully created."
    else
      @sale = result.sale || Sale.new
      @errors = result.errors
      @products = product_options
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sales/:id(.pdf)
  def show
    authorize @sale

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
      redirect_to result.sale, notice: "Cotizacion successfully converted to venta."
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
      redirect_to @sale, notice: "Sale was successfully annulled."
    else
      flash[:alert] = result.errors.join("; ")
      redirect_to @sale
    end
  end

  private

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
