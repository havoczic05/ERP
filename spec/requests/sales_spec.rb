require 'rails_helper'

RSpec.describe 'Sales', type: :request do
  # ---------------------------------------------------------------------------
  # Shared test seam: inject current_user via ApplicationController#current_user=
  # ---------------------------------------------------------------------------
  let(:admin_user)  { create(:user, :administrador) }
  let(:vendor_user) { create(:user, :vendedor) }

  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }
  let(:product)   { create(:product, stock: 100, base_price_usd: 10.00, warehouse: warehouse) }

  def venta_params(num_installments: 1, interval_days: 30, items: nil)
    items ||= [ { product_id: product.id, quantity: 2, unit_price_usd: '10.00' } ]
    {
      sale: {
        client_id:        client.id,
        warehouse_id:     warehouse.id,
        document_type:    'venta',
        num_installments: num_installments,
        interval_days:    interval_days,
        items:            items
      }
    }
  end

  def cotizacion_params
    {
      sale: {
        client_id:        client.id,
        warehouse_id:     warehouse.id,
        document_type:    'cotizacion',
        num_installments: 1,
        interval_days:    30,
        items:            [ { product_id: product.id, quantity: 1, unit_price_usd: '10.00' } ]
      }
    }
  end

  # ---------------------------------------------------------------------------
  # GET /sales — index
  # ---------------------------------------------------------------------------
  describe 'GET /sales' do
    before { login_as(admin_user) }

    it 'returns 200 OK' do
      get sales_path
      expect(response).to have_http_status(:ok)
    end

    it 'shows kept sales and annulled sales (for audit) per spec RF3.1' do
      kept_sale = create(:sale, :venta, client: client, warehouse: warehouse,
                                        correlative: 'VTA-09001')
      annulled  = create(:sale, :venta, :anulada, client: client, warehouse: warehouse,
                                                  correlative: 'VTA-09002')

      get sales_path

      expect(response.body).to include(kept_sale.correlative)
      expect(response.body).to include(annulled.correlative)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /sales/new
  # ---------------------------------------------------------------------------
  describe 'GET /sales/new' do
    before { login_as(admin_user) }

    it 'returns 200 OK' do
      get new_sale_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales — create venta (success)
  # ---------------------------------------------------------------------------
  describe 'POST /sales (create venta — success)' do
    before { login_as(admin_user) }

    it 'creates a Sale and redirects to show' do
      expect {
        post sales_path, params: venta_params
      }.to change(Sale, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response.location).to include('/sales/')
    end

    it 'decrements product stock' do
      product  # force creation
      post sales_path, params: venta_params
      expect(product.reload.stock).to eq(98)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales — create blocked by insufficient stock
  # ---------------------------------------------------------------------------
  describe 'POST /sales (blocked by stock)' do
    before { login_as(admin_user) }

    it 'returns 422 and re-renders new when stock is insufficient' do
      low_product = create(:product, stock: 1, base_price_usd: 10.00, warehouse: warehouse)
      params = venta_params(items: [ { product_id: low_product.id, quantity: 100, unit_price_usd: '10.00' } ])

      post sales_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales — create cotizacion
  # ---------------------------------------------------------------------------
  describe 'POST /sales (create cotizacion)' do
    before { login_as(admin_user) }

    it 'creates a cotizacion without decrementing stock' do
      stock_before = product.stock

      expect {
        post sales_path, params: cotizacion_params
      }.to change(Sale, :count).by(1)

      expect(product.reload.stock).to eq(stock_before)
      expect(Sale.last.document_type).to eq('cotizacion')
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales — create with zero items (rejected)
  # ---------------------------------------------------------------------------
  describe 'POST /sales (no items — rejected)' do
    before { login_as(admin_user) }

    it 'returns 422 when no items are submitted' do
      params = {
        sale: {
          client_id:     client.id,
          warehouse_id:  warehouse.id,
          document_type: 'venta',
          items:         []
        }
      }
      post sales_path, params: params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /sales/:id — show
  # ---------------------------------------------------------------------------
  describe 'GET /sales/:id' do
    before { login_as(admin_user) }

    it 'returns 200 for an existing kept sale' do
      sale = create(:sale, :venta, client: client, warehouse: warehouse)
      get sale_path(sale)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /sales/:id.pdf — RF5.4 PDF export
  # ---------------------------------------------------------------------------
  describe 'GET /sales/:id.pdf' do
    let(:sale) do
      sale = create(:sale, :venta, client: client, warehouse: warehouse)
      create(:sale_item, sale: sale, product: product, quantity: 2,
             unit_price_usd: 10.00, line_total_usd: 20.00)
      sale
    end

    it 'returns a PDF for a logged-in vendedor' do
      login_as(vendor_user)
      get sale_path(sale, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
    end

    it 'names the file after the document correlative' do
      login_as(admin_user)
      get sale_path(sale, format: :pdf)

      expect(response.headers['Content-Disposition']).to include("#{sale.correlative}.pdf")
    end

    it 'redirects to login when unauthenticated' do
      get sale_path(sale, format: :pdf)
      expect(response).to redirect_to(login_path)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales/:id/convert_to_sale — convert cotizacion to venta
  # ---------------------------------------------------------------------------
  describe 'POST /sales/:id/convert_to_sale' do
    let(:cotizacion) do
      sale = create(:sale, client: client, warehouse: warehouse,
                    document_type: 'cotizacion', status: 'confirmada',
                    subtotal_usd: 10.00, total_usd: 10.00)
      create(:sale_item, sale: sale, product: product, quantity: 1,
             unit_price_usd: 10.00, line_total_usd: 10.00)
      sale
    end

    before { login_as(vendor_user) }

    it 'creates a new venta and redirects for vendedor' do
      # Force cotizacion creation before measuring the count delta
      cot_id = cotizacion.id
      cotizacion_path = convert_to_sale_sale_path(cotizacion)

      expect {
        post cotizacion_path, params: { num_installments: 1, interval_days: 30 }
      }.to change(Sale, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(Sale.where(source_cotizacion_id: cot_id).exists?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales/:id/annul — admin can annul
  # ---------------------------------------------------------------------------
  describe 'POST /sales/:id/annul (administrador)' do
    before { login_as(admin_user) }

    let(:venta_with_items) do
      sale = create(:sale, :venta, client: client, warehouse: warehouse,
                    subtotal_usd: 20.00, total_usd: 20.00)
      create(:sale_item, sale: sale, product: product, quantity: 2,
             unit_price_usd: 10.00, line_total_usd: 20.00)
      create(:installment, sale: sale, installment_number: 1, amount_usd: 20.00, balance_usd: 20.00)
      sale
    end

    it 'annuls the sale and redirects' do
      post annul_sale_path(venta_with_items)

      expect(response).to have_http_status(:found)
      expect(venta_with_items.reload.status).to eq('anulada')
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales/:id/annul — vendedor is forbidden (403/redirect)
  # ---------------------------------------------------------------------------
  describe 'POST /sales/:id/annul (vendedor — forbidden)' do
    before { login_as(vendor_user) }

    let(:venta) do
      create(:sale, :venta, client: client, warehouse: warehouse,
             subtotal_usd: 10.00, total_usd: 10.00)
    end

    it 'returns 403 Forbidden for vendedor' do
      post annul_sale_path(venta)

      # Pundit raises Pundit::NotAuthorizedError; controller handles it as forbidden
      expect(response).to have_http_status(:forbidden)
      expect(venta.reload.status).to eq('confirmada')
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization: both roles can create
  # ---------------------------------------------------------------------------
  describe 'authorization — both roles can create' do
    it 'allows administrador to create a venta' do
      login_as(admin_user)
      post sales_path, params: venta_params
      expect(response).to have_http_status(:found)
    end

    it 'allows vendedor to create a venta' do
      login_as(vendor_user)
      post sales_path, params: venta_params
      expect(response).to have_http_status(:found)
    end
  end
end
