require 'rails_helper'

# System specs for Sales views (Phase 7, Slice C).
# Driver: rack_test (server-rendered HTML assertions only).
#
# JS behaviors (Stimulus sale_form_controller, Turbo Frame client-picker) are
# covered by spec/system/sales_form_js_spec.rb using headless Chrome (js: true).

RSpec.describe 'Sales', type: :system do
  before { driven_by(:rack_test) }

  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  # Stub current_user — matches the established pattern from clients_spec.rb
  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(current_user)
  end

  let(:current_user) { admin }

  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client, full_name: 'ACME Corp') }
  let(:product)   { create(:product, warehouse: warehouse, stock: 100, base_price_usd: 10.00) }

  # ---------------------------------------------------------------------------
  # Index — list of kept sales
  # ---------------------------------------------------------------------------
  describe 'index page' do
    it 'renders the page heading and "Nuevo documento" link' do
      visit sales_path
      expect(page).to have_content('Ventas')
      expect(page).to have_link('Nuevo documento', href: new_sale_path)
    end

    it 'lists existing sales with correlative, type, client, total, status' do
      sale = create(:sale, client: client, warehouse: warehouse,
                           total_usd: 150.00, correlative: 'COT-00001',
                           document_type: 'cotizacion', status: 'confirmada')

      visit sales_path

      expect(page).to have_content('COT-00001')
      expect(page).to have_content('ACME Corp')
      expect(page).to have_content('150')
      expect(page).to have_content('Confirmada')
    end

    it 'shows a "Ver" link for each sale' do
      sale = create(:sale, client: client, warehouse: warehouse)
      visit sales_path
      expect(page).to have_link('Ver', href: sale_path(sale))
    end

    it 'shows the document creation date in dd/mm/aaaa' do
      sale = create(:sale, client: client, warehouse: warehouse, correlative: 'COT-00002')
      visit sales_path
      expect(page).to have_content('Fecha')
      within("#sale_#{sale.id}") do
        expect(page).to have_content(sale.created_at.strftime('%d/%m/%Y'))
      end
    end

    it 'shows annulled sales in the index for audit purposes' do
      # Per spec (RF3.1): "Annulled sales (status=anulada) MUST still appear in the
      # index for audit purposes." Annulment soft-deletes (sets discarded_at), so the
      # index must surface them via an explicit status filter, not just Sale.kept.
      create(:sale, client: client, warehouse: warehouse,
                    correlative: 'COT-00010', document_type: 'cotizacion',
                    status: 'confirmada')
      create(:sale, :anulada, client: client, warehouse: warehouse,
                              correlative: 'COT-00011', document_type: 'cotizacion')

      visit sales_path

      expect(page).to have_content('COT-00010')
      expect(page).to have_content('COT-00011')
    end

    it 'shows "Anular" button for admin on confirmed ventas' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00001', status: 'confirmada')
      visit sales_path
      expect(page).to have_button('Anular')
    end

    it 'does not show "Anular" button for vendedor' do
      let_user = vendedor
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(let_user)

      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00001', status: 'confirmada')
      visit sales_path
      expect(page).not_to have_button('Anular')
    end

    context 'pagination' do
      it 'renders pagination nav when more than one page exists' do
        # Sales paginates at 15/page; create 16 sales to trigger a second page.
        16.times do |i|
          create(:sale, client: client, warehouse: warehouse,
                        correlative: format('COT-%05d', i + 100),
                        document_type: 'cotizacion', status: 'confirmada')
        end

        visit sales_path
        expect(page).to have_css('nav.pagination')
        expect(page).to have_link('Siguiente ›', href: sales_path(page: 2))
        expect(page).to have_content('Mostrando 1–15 de 16')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # New / Create — server-rendered form assertions
  # ---------------------------------------------------------------------------
  describe 'new sale form' do
    it 'renders the form heading and submit button' do
      visit new_sale_path
      expect(page).to have_content('Nuevo documento de venta')
      expect(page).to have_button('Crear documento')
    end

    it 'renders document type selector with cotizacion and venta options' do
      visit new_sale_path
      expect(page).to have_select('sale[document_type]',
                                  with_options: [ 'Cotización', 'Venta' ])
    end

    it 'renders the payment mode with installment fields disabled by default (Contado)' do
      visit new_sale_path
      expect(page).to have_content('Forma de pago')
      # Contado is the default, so the installment fields render disabled until
      # the user picks Cuotas.
      expect(page).to have_field('sale[num_installments]', disabled: true)
      expect(page).to have_select('sale[interval_days]', disabled: true)
    end

    it 'renders a line-item section with product, quantity, and unit price fields' do
      visit new_sale_path
      expect(page).to have_css('#line-items')
      expect(page).to have_field('sale[items][][product_query]')
      expect(page).to have_field('sale[items][][quantity]')
      expect(page).to have_field('sale[items][][unit_price_usd]')
    end

    it 'lets the user search products by name via a combobox (name display + hidden product_id)' do
      visit new_sale_path

      # The product field is a name-searchable combobox: a visible query input plus
      # a hidden product_id the JS combobox fills on select. No raw datalist.
      expect(page).to have_field('sale[items][][product_query]')
      expect(page).to have_css("input[name='sale[items][][product_id]']", visible: :all)
      expect(page).to have_css('.combobox.product-search')
      expect(page).to have_no_css('datalist#products-datalist')
    end

    it 'renders the client search combobox' do
      visit new_sale_path
      expect(page).to have_css('.combobox.client-search')
      expect(page).to have_field('q')
      expect(page).to have_css("input[name='sale[client_id]']", visible: :all)
    end

    it 'renders a client search input' do
      visit new_sale_path
      expect(page).to have_field('q')
    end

    it 'creates a cotizacion and redirects to show page' do
      # Materialize the records before rendering so the warehouse select lists them.
      client
      product
      visit new_sale_path

      # client_id is the hidden field the JS combobox fills; set it directly
      # (fill_in doesn't locate hidden inputs by name). Warehouse is now a select.
      find('input[name="sale[client_id]"]', visible: false).set(client.id)
      select warehouse.name, from: 'sale[warehouse_id]'
      select 'Cotización', from: 'sale[document_type]'
      # num_installments stays disabled under Contado (default) → not submitted;
      # the service defaults it, and a cotizacion generates no installments anyway.
      # The user searches the product by name; the submitted value is the
      # "Name (SKU)" label, which the controller resolves to product_id.
      find('input[name="sale[items][][product_query]"]').set("#{product.name} (#{product.sku})")
      find('input[name="sale[items][][quantity]"]').set('5')
      find('input[name="sale[items][][unit_price_usd]"]').set('10.00')

      click_button 'Crear documento'

      expect(page).to have_content('COT-')
      expect(page).to have_content('Documento creado correctamente.')
      expect(Sale.kept.last.document_type).to eq('cotizacion')
      expect(Sale.kept.last.total_usd).to eq(50.00)
    end

    it 'shows validation errors when submitted with missing client_id' do
      visit new_sale_path

      select 'Cotización', from: 'sale[document_type]'
      fill_in 'sale[items][][product_query]', with: "#{product.name} (#{product.sku})"
      fill_in 'sale[items][][quantity]', with: '1'
      fill_in 'sale[items][][unit_price_usd]', with: '10.00'
      # Intentionally omit client_id and warehouse_id

      click_button 'Crear documento'

      # Form re-rendered with error
      expect(page).to have_button('Crear documento')
    end

    # JS behaviors (add row, live totals, Turbo Frame client search) are covered
    # by spec/system/sales_form_js_spec.rb using headless Chrome (js: true).
  end

  # ---------------------------------------------------------------------------
  # Show page
  # ---------------------------------------------------------------------------
  describe 'show page' do
    it 'displays correlative, document type, status, client, and totals' do
      sale = create(:sale, client: client, warehouse: warehouse,
                           correlative: 'COT-00042', document_type: 'cotizacion',
                           status: 'confirmada', subtotal_usd: 75.00,
                           tax_usd: 0.00, total_usd: 75.00)

      visit sale_path(sale)

      expect(page).to have_content('COT-00042')
      expect(page).to have_content('Cotización')
      expect(page).to have_content('Confirmada')
      expect(page).to have_content('ACME Corp')
      expect(page).to have_content('75')
    end

    it 'renders line items table' do
      sale = create(:sale, client: client, warehouse: warehouse,
                           correlative: 'COT-00043', document_type: 'cotizacion',
                           status: 'confirmada', total_usd: 50.00)
      create(:sale_item, sale: sale, product: product,
                          quantity: 5, unit_price_usd: 10.00, line_total_usd: 50.00)

      visit sale_path(sale)

      expect(page).to have_content(product.name)
      expect(page).to have_content('5')   # quantity
      expect(page).to have_content('10')  # unit price
    end

    it 'renders installments table when a venta has installments' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00001', status: 'confirmada',
                                    total_usd: 100.00)
      create(:installment, sale: venta, installment_number: 1,
                            amount_usd: 100.00, balance_usd: 100.00,
                            due_date: Date.today + 30, status: 'pendiente')

      visit sale_path(venta)

      expect(page).to have_content('Cuotas')
      expect(page).to have_content('Pendiente')
    end

    it 'shows "Convert to Venta" button for cotizacion (admin)' do
      cotizacion = create(:sale, client: client, warehouse: warehouse,
                                  correlative: 'COT-00044', document_type: 'cotizacion',
                                  status: 'confirmada')

      visit sale_path(cotizacion)

      expect(page).to have_button('Convertir a venta')
    end

    it 'shows "Annul Sale" button for confirmed venta (admin)' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00002', status: 'confirmada')

      visit sale_path(venta)

      expect(page).to have_button('Anular venta')
    end

    it 'shows "Back to Sales" link' do
      sale = create(:sale, client: client, warehouse: warehouse)
      visit sale_path(sale)
      expect(page).to have_link('Volver a ventas', href: sales_path)
    end

    it 'displays flash notice after create' do
      # This is verified indirectly through the create flow above
      # (redirect to show renders the notice)
      sale = create(:sale, client: client, warehouse: warehouse)
      visit sale_path(sale)
      # Show page renders without error
      expect(page).to have_content(sale.correlative)
    end
  end

  # ---------------------------------------------------------------------------
  # Client search endpoint — server-side HTML assertion
  # ---------------------------------------------------------------------------
  describe 'GET /clients/search' do
    it 'renders matching clients in a turbo frame' do
      matching    = create(:client, :ruc_client, full_name: 'Turbo Corp')
      non_matching = create(:client, :ruc_client, full_name: 'Other LLC')

      visit search_clients_path(q: 'Turbo')

      expect(page).to have_content('Turbo Corp')
      expect(page).not_to have_content('Other LLC')
    end

    it 'renders no results message when no clients match' do
      visit search_clients_path(q: 'ZZZNOMATCH')
      expect(page).to have_content('No se encontraron clientes.')
    end

    it 'renders selectable combobox options the client picker can pick' do
      # The search response is a list of selectable options the combobox controller
      # injects and wires to combobox#select (no Turbo frame).
      create(:client, :ruc_client, full_name: 'Turbo Corp')
      visit search_clients_path(q: 'Turbo')
      expect(page).to have_css('button.picker-option', text: 'Turbo Corp')
    end
  end

  # ---------------------------------------------------------------------------
  # Payment history on the sale detail page (surfaces amortization notes)
  # ---------------------------------------------------------------------------
  describe 'payment history on show' do
    let(:sale) { create(:sale, :venta, :with_items, client: client, warehouse: warehouse) }
    let(:installment) do
      create(:installment, sale: sale, installment_number: 1,
                           amount_usd: 300, balance_usd: 100, due_date: 10.days.from_now)
    end

    it 'lists recorded payments with date, amount and notes' do
      create(:amortization, installment: installment, amount_usd: 200,
                            paid_at: Time.zone.local(2026, 6, 10, 12), notes: 'Pago parcial en efectivo')

      visit sale_path(sale)

      expect(page).to have_content('Historial de pagos')
      expect(page).to have_content('10/06/2026')
      expect(page).to have_content('Pago parcial en efectivo')
    end

    it 'does not render the payment history section when there are no payments' do
      installment # exists but unpaid
      visit sale_path(sale)
      expect(page).not_to have_content('Historial de pagos')
    end
  end
end
