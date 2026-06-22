class ProductsController < ApplicationController
  before_action :set_product, only: %i[show edit update destroy]

  def index
    scope = Product.kept.order(:name)
    scope = search_products(scope, params[:q]) if params[:q].present?
    scope = scope.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
    @pagy, @products = pagy(:offset, scope)
    @warehouses = Warehouse.order(:name)
    authorize Product
  end

  def search
    authorize Product, :search?
    term = params[:q].to_s.strip
    scope = Product.kept
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
      redirect_to @product, notice: "Producto creado correctamente."
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
      redirect_to @product, notice: "Producto actualizado correctamente."
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
      flash.now[:alert] = "No se puede eliminar este producto porque tiene ítems de venta asociados."
      render :show, status: :unprocessable_entity
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
end
