class ProductsController < ApplicationController
  include CsvExport

  before_action :set_product, only: %i[show edit update destroy]

  CSV_HEADERS = [ "SKU", "Nombre", "Marca", "Almacén", "Stock", "Precio base USD" ].freeze

  def index
    authorize Product
    scope = Product.kept.order(:name)
    scope = search_products(scope, params[:q]) if params[:q].present?
    scope = scope.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
    @warehouses = Warehouse.order(:name)

    respond_to do |format|
      format.html { @pagy, @products = pagy(:offset, scope, limit: 10) }
      format.csv { send_csv("productos", CSV_HEADERS, products_csv_rows(scope)) }
    end
  end

  def search
    authorize Product, :search?
    term = params[:q].to_s.strip
    scope = Product.kept
    scope = scope.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
    @products = term.present? ? search_products(scope, term) : scope.none
    render partial: "products/results"
  end

  def show
    authorize @product
  end

  def new
    @product = Product.new
    authorize @product
    @warehouses = Warehouse.order(:name)
  end

  def create
    @product = Product.new(product_create_params)
    authorize @product

    if @product.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: product_saved_streams(@product, "Producto creado correctamente.", prepend: true) }
        format.html { redirect_to @product, notice: "Producto creado correctamente." }
      end
    else
      @warehouses = Warehouse.order(:name)
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "is already taken")
    @warehouses = Warehouse.order(:name)
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @product
    @warehouses = Warehouse.order(:name)
  end

  def update
    authorize @product

    if @product.update(product_update_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: product_saved_streams(@product, "Producto actualizado correctamente.", prepend: false) }
        format.html { redirect_to @product, notice: "Producto actualizado correctamente." }
      end
    else
      @warehouses = Warehouse.order(:name)
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "is already taken")
    @warehouses = Warehouse.order(:name)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize @product

    if @product.destroyable?
      @product.discard
      redirect_to products_path, notice: "Producto archivado correctamente."
    else
      redirect_to products_path, alert: "No se puede eliminar este producto porque tiene ítems de venta asociados."
    end
  end

  private

  def set_product
    @product = Product.kept.find(params[:id])
  end

  # stock is permitted ONLY at creation — never at update
  def product_create_params
    params.require(:product).permit(:sku, :name, :brand, :warehouse_id, :stock, :base_price_usd)
  end

  # stock intentionally OMITTED — server-side write-once invariant (RF-PM-3)
  def product_update_params
    params.require(:product).permit(:sku, :name, :brand, :warehouse_id, :base_price_usd)
  end

  def search_products(scope, query)
    term = query.to_s.strip
    return scope if term.blank?

    scope.where("name ILIKE :q OR sku ILIKE :q", q: "%#{term}%")
  end

  # Turbo Stream set for a saved product: close the modal, refresh its table row
  # (prepend for new, replace for existing) and append a confirmation toast.
  def product_saved_streams(product, message, prepend:)
    row = if prepend
            turbo_stream.prepend("products", partial: "products/product", locals: { product: product })
    else
            turbo_stream.replace(product, partial: "products/product", locals: { product: product })
    end

    [
      turbo_stream.update("modal", ""),
      row,
      turbo_stream.append("toasts", partial: "layouts/toast", locals: { kind: :notice, message: message })
    ]
  end

  def products_csv_rows(scope)
    scope.includes(:warehouse).map do |product|
      [
        product.sku,
        product.name,
        product.brand,
        product.warehouse&.name,
        product.stock,
        product.base_price_usd
      ]
    end
  end
end
