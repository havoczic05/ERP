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
      respond_to do |format|
        format.turbo_stream { render turbo_stream: warehouse_saved_streams(@warehouse, "Almacén creado correctamente.", prepend: true) }
        format.html { redirect_to @warehouse, notice: "Almacén creado correctamente." }
      end
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
      respond_to do |format|
        format.turbo_stream { render turbo_stream: warehouse_saved_streams(@warehouse, "Almacén actualizado correctamente.", prepend: false) }
        format.html { redirect_to @warehouse, notice: "Almacén actualizado correctamente." }
      end
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
      redirect_to warehouses_path, alert: "No se puede eliminar este almacén porque tiene productos o ventas asociadas."
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :location)
  end

  # Turbo Stream set for a saved warehouse: close the modal, refresh its table
  # row (prepend for new, replace for existing) and append a confirmation toast.
  def warehouse_saved_streams(warehouse, message, prepend:)
    row = if prepend
            turbo_stream.prepend("warehouses", partial: "warehouses/warehouse", locals: { warehouse: warehouse })
    else
            turbo_stream.replace(warehouse, partial: "warehouses/warehouse", locals: { warehouse: warehouse })
    end

    [
      turbo_stream.update("modal", ""),
      row,
      turbo_stream.append("toasts", partial: "layouts/toast", locals: { kind: :notice, message: message })
    ]
  end
end
