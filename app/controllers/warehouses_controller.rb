class WarehousesController < ApplicationController
  before_action :set_warehouse, only: %i[show edit update destroy]

  def index
    scope = Warehouse.all.order(:name)
    @pagy, @warehouses = pagy(:offset, scope)
    authorize Warehouse
  end

  def show
    authorize @warehouse
  end

  def new
    @warehouse = Warehouse.new
    authorize @warehouse
  end

  def create
    @warehouse = Warehouse.new(warehouse_params)
    authorize @warehouse

    if @warehouse.save
      redirect_to @warehouse, notice: "Almacén creado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @warehouse
  end

  def update
    authorize @warehouse

    if @warehouse.update(warehouse_params)
      redirect_to @warehouse, notice: "Almacén actualizado correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @warehouse

    if @warehouse.destroyable?
      @warehouse.destroy
      redirect_to warehouses_path, notice: "Almacén eliminado correctamente."
    else
      flash.now[:alert] = "No se puede eliminar este almacén porque tiene productos o ventas asociadas."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :location)
  end
end
