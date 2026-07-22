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

    context 'filters and CSV export' do
      let!(:acme)  { create(:client, :ruc_client, full_name: 'Acme Corp') }
      let!(:beta)  { create(:client, :ruc_client, full_name: 'Beta SA') }
      let!(:venta_acme) do
        create(:sale, :venta, client: acme, warehouse: warehouse, correlative: 'VTA-F001', total_usd: 100)
      end
      let!(:cotiz_beta) do
        create(:sale, client: beta, warehouse: warehouse, document_type: 'cotizacion',
                      correlative: 'COT-F001', total_usd: 50)
      end
      let!(:anulada_acme) do
        create(:sale, :venta, :anulada, client: acme, warehouse: warehouse,
                                        correlative: 'VTA-F002', total_usd: 200)
      end

      it 'filters by client name (q)' do
        get sales_path(q: 'Acme')
        expect(response.body).to include('VTA-F001')
        expect(response.body).not_to include('COT-F001')
      end

      it 'filters by document_type and status' do
        get sales_path(document_type: 'cotizacion')
        expect(response.body).to include('COT-F001')
        expect(response.body).not_to include('VTA-F001')

        get sales_path(status: 'anulada')
        expect(response.body).to include('VTA-F002')
        expect(response.body).not_to include('VTA-F001')
      end

      it 'ignores unknown filter values (no error)' do
        get sales_path(status: 'bogus', document_type: 'bogus')
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('VTA-F001')
      end

      it 'exports the filtered set as CSV (respects filters)' do
        get sales_path(format: :csv, q: 'Acme')
        expect(response.media_type).to eq('text/csv')
        expect(response.body).to include('Correlativo,Fecha,Tipo,Cliente,Total (USD),Estado')
        expect(response.body).to include('VTA-F001')
        expect(response.body).to include('Acme Corp')
        expect(response.body).not_to include('COT-F001')
      end
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
  # POST /sales — create venta with an explicit editable installment plan
  # ---------------------------------------------------------------------------
  describe 'POST /sales (create venta — explicit installment plan)' do
    before { login_as(admin_user) }

    it 'persists the submitted dates and amounts when the sum matches the total' do
      # 2 units x 10.00 = 20.00 total, split 12.00 + 8.00 across two dates.
      params = venta_params.deep_merge(
        sale: {
          installments: [
            { due_date: '2026-08-15', amount_usd: '12.00' },
            { due_date: '2026-09-15', amount_usd: '8.00' }
          ]
        }
      )

      expect {
        post sales_path, params: params
      }.to change(Sale, :count).by(1)

      sale = Sale.last
      rows = sale.installments.order(:installment_number)
      expect(rows.pluck(:amount_usd).map(&:to_d)).to eq([ BigDecimal('12.00'), BigDecimal('8.00') ])
      expect(rows.pluck(:due_date)).to eq([ Date.new(2026, 8, 15), Date.new(2026, 9, 15) ])
    end

    it 'returns 422 when the installment sum does not match the total' do
      params = venta_params.deep_merge(
        sale: {
          installments: [
            { due_date: '2026-08-15', amount_usd: '5.00' },
            { due_date: '2026-09-15', amount_usd: '5.00' } # 10 != 20
          ]
        }
      )

      post sales_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Sale.count).to eq(0)
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

    it 'sets flash[:alert] with the error message (R1)' do
      low_product = create(:product, stock: 1, base_price_usd: 10.00, warehouse: warehouse)
      params = venta_params(items: [ { product_id: low_product.id, quantity: 100, unit_price_usd: '10.00' } ])

      post sales_path, params: params

      expect(flash[:alert]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # POST /sales — item preservation on failure (stock-validation SC-01, SC-04)
  # ---------------------------------------------------------------------------
  describe 'POST /sales (item preservation on failure)' do
    before { login_as(admin_user) }

    it 'preserves submitted line items on re-render (SC-01)' do
      low_product = create(:product, stock: 1, base_price_usd: 50.00,
                            warehouse: warehouse, name: 'Laptop', sku: 'LP-001')
      params = venta_params(items: [ { product_id: low_product.id, quantity: 100,
                                       unit_price_usd: '1500.00' } ])

      post sales_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      # product_query repopulated via line_items_from_params
      expect(response.body).to include('Laptop (LP-001)')
      # product_id hidden field preserved
      expect(response.body).to include("value=\"#{low_product.id}\"")
      # quantity preserved
      expect(response.body).to include('value="100"')
    end

    it 'repopulates product_query as "Name (SKU)" (SC-03)' do
      low_product = create(:product, stock: 1, base_price_usd: 10.00,
                            warehouse: warehouse, name: 'Teclado', sku: 'KEY-999')
      params = venta_params(items: [ { product_id: low_product.id, quantity: 50,
                                       unit_price_usd: '99.00' } ])

      post sales_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      # product_query must be "Teclado (KEY-999)"
      input_html = response.body.match(
        /name="sale\[items\]\[\]\[product_query\]"[^>]*value="([^"]*)"/
      )
      expect(input_html).not_to be_nil
      expect(input_html[1]).to eq("Teclado (KEY-999)")
    end

    it 'returns items structure compatible with _form_fields partial (SC-04)' do
      low_product = create(:product, stock: 1, base_price_usd: 10.00,
                            warehouse: warehouse, name: 'Mouse', sku: 'MOU-999')
      params = venta_params(items: [ { product_id: low_product.id, quantity: 3,
                                       unit_price_usd: '25.00' } ])

      post sales_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      # The partial iterates line_items — must find product_id hidden field,
      # product_query input, quantity input, and unit_price input for the item.
      expect(response.body).to include("value=\"#{low_product.id}\"")
      expect(response.body).to include('Mouse (MOU-999)')
      expect(response.body).to include('value="3"')
      expect(response.body).to include('value="25.00"')
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

    it 'sets flash[:alert] when no items are submitted (R1, R2)' do
      params = {
        sale: {
          client_id:     client.id,
          warehouse_id:  warehouse.id,
          document_type: 'venta',
          items:         []
        }
      }
      post sales_path, params: params
      expect(flash[:alert]).to be_present
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

    it 'opens the PDF link in a new window' do
      sale = create(:sale, :venta, client: client, warehouse: warehouse)
      get sale_path(sale)
      expect(response.body).to include(sale_path(sale, format: :pdf))
      expect(response.body).to include('target="_blank"')
    end

    it 'shows the installment plan with running balance and payment date columns' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                     subtotal_usd: 400.00, total_usd: 400.00)
      i1 = create(:installment, sale: venta, installment_number: 1,
                  amount_usd: 200.00, balance_usd: 0.00, status: 'pagada',
                  due_date: Date.new(2026, 8, 4))
      create(:amortization, installment: i1, amount_usd: 200.00,
             paid_at: Time.zone.local(2026, 8, 4, 10))
      create(:installment, sale: venta, installment_number: 2,
             amount_usd: 200.00, balance_usd: 200.00, status: 'pendiente',
             due_date: Date.new(2026, 9, 3))

      get sale_path(venta)

      expect(response.body).to include('Saldo restante')
      expect(response.body).to include('Fecha de pago')
      # Running outstanding: 400 before cuota 1, 200 before cuota 2.
      expect(response.body).to include('04/08/2026')
      # The info tooltip trigger is present and labelled for assistive tech.
      expect(response.body).to include('Cómo se calcula el saldo restante')
    end

    it 'no longer renders a separate payment history section' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse)
      get sale_path(venta)
      expect(response.body).not_to include('Historial de pagos')
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

    it 'returns a PDF named "-cuotas" when cuotas=true' do
      login_as(admin_user)
      get sale_path(sale, format: :pdf, cuotas: true)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
      expect(response.headers['Content-Disposition']).to include("#{sale.correlative}-cuotas.pdf")
    end
  end

  # ---------------------------------------------------------------------------
  # Two-step conversion: GET the editable form, then POST the built venta.
  # ---------------------------------------------------------------------------
  describe 'cotizacion → venta conversion (two-step editable flow)' do
    let(:cotizacion) do
      sale = create(:sale, client: client, warehouse: warehouse,
                    document_type: 'cotizacion', status: 'confirmada',
                    subtotal_usd: 10.00, total_usd: 10.00)
      create(:sale_item, sale: sale, product: product, quantity: 1,
             unit_price_usd: 10.00, line_total_usd: 10.00)
      sale
    end

    # Full editable-form payload, mirroring what the browser submits.
    def conversion_payload(items: nil, installments: nil)
      items ||= [ { product_id: product.id, quantity: 1, unit_price_usd: '10.00' } ]
      sale = {
        client_id:     client.id,
        warehouse_id:  warehouse.id,
        document_type: 'venta',
        notes:         cotizacion.notes,
        items:         items
      }
      sale[:installments] = installments if installments
      { sale: sale }
    end

    before { login_as(vendor_user) }

    describe 'GET /sales/:id/convert' do
      it 'renders the editable convert form preloaded from the cotizacion' do
        get convert_sale_path(cotizacion)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Convertir')
        expect(response.body).to include(cotizacion.correlative)
      end

      it 'redirects with an alert when the cotizacion was already converted' do
        SaleCreationService.call(conversion_payload[:sale].merge(source_cotizacion_id: cotizacion.id))

        get convert_sale_path(cotizacion)

        expect(response).to redirect_to(cotizacion)
        follow_redirect!
        expect(response.body).to include('ya')
      end

      it 'redirects when the document is already a venta' do
        venta = create(:sale, :venta, client: client, warehouse: warehouse)

        get convert_sale_path(venta)

        expect(response).to redirect_to(venta)
      end
    end

    describe 'POST /sales/:id/convert_to_sale' do
      it 'creates a new venta linked to the cotizacion and redirects' do
        cot_id = cotizacion.id

        expect {
          post convert_to_sale_sale_path(cotizacion), params: conversion_payload
        }.to change(Sale.where(document_type: 'venta'), :count).by(1)

        expect(response).to have_http_status(:found)
        venta = Sale.find_by(source_cotizacion_id: cot_id)
        expect(venta).to be_present
        expect(response).to redirect_to(venta)
      end

      it 'persists the editable installment plan submitted with the form' do
        installments = [
          { due_date: '2026-08-01', amount_usd: '4.00' },
          { due_date: '2026-09-01', amount_usd: '6.00' }
        ]

        post convert_to_sale_sale_path(cotizacion), params: conversion_payload(installments: installments)

        venta = Sale.find_by(source_cotizacion_id: cotizacion.id)
        expect(venta.installments.count).to eq(2)
        expect(venta.installments.pluck(:amount_usd).map(&:to_d).sum).to eq(BigDecimal('10.00'))
      end

      it 're-renders the form when the cotizacion was already converted' do
        SaleCreationService.call(conversion_payload[:sale].merge(source_cotizacion_id: cotizacion.id))

        expect {
          post convert_to_sale_sale_path(cotizacion), params: conversion_payload
        }.not_to change(Sale, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('ya')
      end

      it 'sets flash[:alert] when conversion is blocked (R4)' do
        SaleCreationService.call(conversion_payload[:sale].merge(source_cotizacion_id: cotizacion.id))

        post convert_to_sale_sale_path(cotizacion), params: conversion_payload

        expect(flash[:alert]).to be_present
      end

      it 'preserves submitted items on convert_to_sale failure (SC-02)' do
        scarce = create(:product, stock: 1, base_price_usd: 50.00,
                        warehouse: warehouse, name: 'Scarce Item', sku: 'SCA-001')
        overstock_params = conversion_payload(
          items: [ { product_id: scarce.id, quantity: 100, unit_price_usd: '50.00' } ]
        )

        post convert_to_sale_sale_path(cotizacion), params: overstock_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Scarce Item (SCA-001)')
        expect(response.body).to include('value="100"')
      end
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
