class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy]

  def index
    scope = Client.kept.order(:full_name)
    scope = search_clients(scope, params[:q]) if params[:q].present?
    @pagy, @clients = pagy(:offset, scope)
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
      redirect_to @client, notice: "Client was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @client.errors.add(:document_number, "is already registered")
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @client
  end

  def update
    authorize @client

    if @client.update(client_params)
      redirect_to @client, notice: "Client was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @client.errors.add(:document_number, "is already registered")
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize @client

    if @client.destroyable?
      @client.discard
      redirect_to clients_path, notice: "Client was successfully archived."
    else
      flash.now[:alert] = "This client cannot be deleted because it has associated sales."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = Client.kept.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:full_name, :document_type, :document_number, :phone)
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
