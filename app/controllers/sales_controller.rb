class SalesController < ApplicationController
  before_action :set_sale,        only: %i[show]
  before_action :set_kept_sale,   only: %i[annul convert_to_sale]

  # GET /sales
  def index
    authorize Sale
    scope = Sale.kept.order(created_at: :desc)
    @pagy, @sales = pagy(:offset, scope)
  end

  # GET /sales/new
  def new
    @sale = Sale.new
    authorize @sale
  end

  # POST /sales
  def create
    @sale = Sale.new
    authorize @sale

    result = SaleCreationService.call(sale_creation_params)

    if result.success?
      redirect_to result.sale, notice: 'Document was successfully created.'
    else
      @sale = result.sale || Sale.new
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sales/:id
  def show
    authorize @sale
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
      redirect_to result.sale, notice: 'Cotizacion successfully converted to venta.'
    else
      flash[:alert] = result.errors.join('; ')
      redirect_to @sale
    end
  end

  # POST /sales/:id/annul
  def annul
    authorize @sale, :annul?

    result = SaleAnnulmentService.call(@sale, current_user)

    if result.success?
      redirect_to @sale, notice: 'Sale was successfully annulled.'
    else
      flash[:alert] = result.errors.join('; ')
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
      items: %i[product_id quantity unit_price_usd]
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
          product_id:     item[:product_id].to_i,
          quantity:       item[:quantity].to_i,
          unit_price_usd: item[:unit_price_usd]
        }
      end
    }
  end
end
