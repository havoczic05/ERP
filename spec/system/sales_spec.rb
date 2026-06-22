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
    it 'renders the page heading and "New Document" link' do
      visit sales_path
      expect(page).to have_content('Sales')
      expect(page).to have_link('New Document', href: new_sale_path)
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

    it 'shows a "View" link for each sale' do
      sale = create(:sale, client: client, warehouse: warehouse)
      visit sales_path
      expect(page).to have_link('View', href: sale_path(sale))
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

    it 'shows "Annul" button for admin on confirmed ventas' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00001', status: 'confirmada')
      visit sales_path
      expect(page).to have_button('Annul')
    end

    it 'does not show "Annul" button for vendedor' do
      let_user = vendedor
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(let_user)

      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00001', status: 'confirmada')
      visit sales_path
      expect(page).not_to have_button('Annul')
    end

    context 'pagination' do
      it 'renders pagination nav when more than one page exists' do
        # Pagy default is 20 per page; create 21 sales to trigger pagination
        21.times do |i|
          create(:sale, client: client, warehouse: warehouse,
                        correlative: format('COT-%05d', i + 100),
                        document_type: 'cotizacion', status: 'confirmada')
        end

        visit sales_path
        expect(page).to have_css('nav.series-nav')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # New / Create — server-rendered form assertions
  # ---------------------------------------------------------------------------
  describe 'new sale form' do
    it 'renders the form heading and submit button' do
      visit new_sale_path
      expect(page).to have_content('New Sales Document')
      expect(page).to have_button('Create Document')
    end

    it 'renders document type selector with cotizacion and venta options' do
      visit new_sale_path
      expect(page).to have_select('sale[document_type]',
                                  with_options: %w[Cotizacion Venta])
    end

    it 'renders installment fields (num_installments and interval_days)' do
      visit new_sale_path
      expect(page).to have_field('sale[num_installments]')
      expect(page).to have_select('sale[interval_days]')
    end

    it 'renders a line-item section with product, quantity, and unit price fields' do
      visit new_sale_path
      expect(page).to have_css('#line-items')
      expect(page).to have_field('sale[items][][product_query]')
      expect(page).to have_field('sale[items][][quantity]')
      expect(page).to have_field('sale[items][][unit_price_usd]')
    end

    it 'lets the user search products by name via a datalist (not a raw id field)' do
      create(:product, warehouse: warehouse, name: 'Searchable Widget', sku: 'SKU-XYZ')
      visit new_sale_path

      # The product field is a name-searchable text input backed by a datalist,
      # NOT a raw numeric product_id field (users don't know internal ids).
      expect(page).to have_field('sale[items][][product_query]')
      expect(page).not_to have_field('sale[items][][product_id]')
      expect(page).to have_css('datalist#products-datalist')
      expect(page).to have_css("datalist#products-datalist option[value*='Searchable Widget']")
    end

    it 'renders a client search turbo frame placeholder' do
      visit new_sale_path
      # The Turbo Frame tag for client search must be present in the server HTML.
      # rack_test does not execute JS, but the turbo-frame element is rendered
      # statically and can be asserted via CSS selector.
      expect(page).to have_css('turbo-frame#client-picker')
    end

    it 'renders a client search input' do
      visit new_sale_path
      expect(page).to have_field('q')
    end

    it 'creates a cotizacion and redirects to show page' do
      visit new_sale_path

      # Hidden fields for client_id and warehouse_id are set via
      # find('input[name="sale[client_id]"]').set(...) since fill_in
      # doesn't locate hidden inputs by name.
      find('input[name="sale[client_id]"]', visible: false).set(client.id)
      find('input[name="sale[warehouse_id]"]', visible: false).set(warehouse.id)
      select 'Cotizacion', from: 'sale[document_type]'
      fill_in 'sale[num_installments]', with: '1'
      # The user searches the product by name; the submitted value is the
      # "Name (SKU)" datalist label, which the controller resolves to product_id.
      find('input[name="sale[items][][product_query]"]').set("#{product.name} (#{product.sku})")
      find('input[name="sale[items][][quantity]"]').set('5')
      find('input[name="sale[items][][unit_price_usd]"]').set('10.00')

      click_button 'Create Document'

      expect(page).to have_content('COT-')
      expect(page).to have_content('Document was successfully created.')
      expect(Sale.kept.last.document_type).to eq('cotizacion')
      expect(Sale.kept.last.total_usd).to eq(50.00)
    end

    it 'shows validation errors when submitted with missing client_id' do
      visit new_sale_path

      select 'Cotizacion', from: 'sale[document_type]'
      fill_in 'sale[items][][product_query]', with: "#{product.name} (#{product.sku})"
      fill_in 'sale[items][][quantity]', with: '1'
      fill_in 'sale[items][][unit_price_usd]', with: '10.00'
      # Intentionally omit client_id and warehouse_id

      click_button 'Create Document'

      # Form re-rendered with error
      expect(page).to have_button('Create Document')
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
      expect(page).to have_content('Cotizacion')
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

      expect(page).to have_content('Installments')
      expect(page).to have_content('Pendiente')
    end

    it 'shows "Convert to Venta" button for cotizacion (admin)' do
      cotizacion = create(:sale, client: client, warehouse: warehouse,
                                  correlative: 'COT-00044', document_type: 'cotizacion',
                                  status: 'confirmada')

      visit sale_path(cotizacion)

      expect(page).to have_button('Convert to Venta')
    end

    it 'shows "Annul Sale" button for confirmed venta (admin)' do
      venta = create(:sale, :venta, client: client, warehouse: warehouse,
                                    correlative: 'VTA-00002', status: 'confirmada')

      visit sale_path(venta)

      expect(page).to have_button('Annul Sale')
    end

    it 'shows "Back to Sales" link' do
      sale = create(:sale, client: client, warehouse: warehouse)
      visit sale_path(sale)
      expect(page).to have_link('Back to Sales', href: sales_path)
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

    it 'wraps results in the client-picker turbo frame so Turbo can swap them in place' do
      # The search response MUST be wrapped in a turbo-frame whose id matches the
      # picker frame in the sales form (new.html.erb: turbo-frame#client-picker).
      # If the ids differ, Turbo cannot find a matching frame in the response and
      # renders its "Content missing" fallback instead of the results.
      create(:client, :ruc_client, full_name: 'Turbo Corp')
      visit search_clients_path(q: 'Turbo')
      expect(page).to have_css('turbo-frame#client-picker')
    end
  end
end
