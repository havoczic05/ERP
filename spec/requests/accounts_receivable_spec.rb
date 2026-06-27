require 'rails_helper'

RSpec.describe 'AccountsReceivable', type: :request do
  # ---------------------------------------------------------------------------
  # Shared seam: inject current_user via ApplicationController#current_user=
  # ---------------------------------------------------------------------------
  let(:admin_user) { create(:user, :administrador) }

  let(:sale)   { create(:sale, :venta, :with_items) }
  let(:client) { sale.client }

  # ---------------------------------------------------------------------------
  # AR-01: index shows only pending installments (pagada excluded)
  # ---------------------------------------------------------------------------
  describe 'GET /accounts_receivable' do
    context 'as authenticated admin' do
      before { login_as(admin_user) }

      it 'returns 200' do
        get accounts_receivable_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes a pending installment in the response body' do
        installment = create(:installment, sale: sale,
                                           status: 'pendiente',
                                           due_date: 10.days.from_now,
                                           amount_usd: 300.00,
                                           balance_usd: 300.00)

        get accounts_receivable_path

        expect(response.body).to include(client.full_name)
        expect(response.body).to include(sale.correlative)
      end

      it 'excludes a pagada installment from the response body' do
        pagada = create(:installment, sale: sale,
                                      status: 'pagada',
                                      due_date: 5.days.from_now,
                                      amount_usd: 100.00,
                                      balance_usd: 0.00)

        # Create a second, pendiente installment so we know the page renders rows
        create(:installment, sale: sale,
                              installment_number: 2,
                              status: 'pendiente',
                              due_date: 15.days.from_now,
                              amount_usd: 200.00,
                              balance_usd: 200.00)

        get accounts_receivable_path

        # The pagada installment should not appear; we check its specific balance
        # that distinguishes it from the pendiente row.
        expect(response.body).not_to include('Pagada')
      end

      it 'shows an overdue indicator for a past-due installment' do
        create(:installment, sale: sale,
                              status: 'pendiente',
                              due_date: 1.day.ago,
                              amount_usd: 150.00,
                              balance_usd: 150.00)

        get accounts_receivable_path

        # Assert on the danger badge element, not the bare word "Vencida"
        # (the estado filter select also contains that label).
        expect(response.body).to include('badge--danger')
      end

      it 'does not show overdue indicator for an installment due today' do
        create(:installment, sale: sale,
                              status: 'pendiente',
                              due_date: Date.current,
                              amount_usd: 150.00,
                              balance_usd: 150.00)

        get accounts_receivable_path

        expect(response.body).not_to include('badge--danger')
      end
    end

    # -------------------------------------------------------------------------
    # Filters (toolbar mirroring sales): q, estado, vencimiento
    # -------------------------------------------------------------------------
    context 'filters' do
      before { login_as(admin_user) }

      let(:acme)      { create(:client, :ruc_client, full_name: 'Acme Corp') }
      let(:beta)      { create(:client, :ruc_client, full_name: 'Beta SA') }
      let(:acme_sale) { create(:sale, :venta, client: acme, correlative: 'VTA-AAA01') }
      let(:beta_sale) { create(:sale, :venta, client: beta, correlative: 'VTA-BBB01') }

      let!(:acme_inst) do
        create(:installment, sale: acme_sale, status: 'pendiente',
                             due_date: 10.days.from_now, amount_usd: 100, balance_usd: 100)
      end
      let!(:beta_inst) do
        create(:installment, sale: beta_sale, status: 'pendiente',
                             due_date: 20.days.from_now, amount_usd: 200, balance_usd: 200)
      end

      it 'filters by client name (q)' do
        get accounts_receivable_path(q: 'Acme')
        expect(response.body).to include('Acme Corp')
        expect(response.body).not_to include('Beta SA')
      end

      it 'filters by sale correlative (q)' do
        get accounts_receivable_path(q: 'BBB01')
        expect(response.body).to include('Beta SA')
        expect(response.body).not_to include('Acme Corp')
      end

      it 'filters by estado=vencida (past-due within outstanding)' do
        create(:installment, sale: acme_sale, installment_number: 2, status: 'pendiente',
                             due_date: 2.days.ago, amount_usd: 50, balance_usd: 50)
        get accounts_receivable_path(status: 'vencida')
        expect(response.body).to include('Acme Corp')   # only its overdue row passes
        expect(response.body).not_to include('Beta SA') # 20 days out → excluded
      end

      it 'filters by estado=pendiente (not yet due)' do
        create(:installment, sale: acme_sale, installment_number: 2, status: 'pendiente',
                             due_date: 2.days.ago, amount_usd: 50, balance_usd: 50)
        get accounts_receivable_path(status: 'pendiente')
        expect(response.body).to include('Beta SA')     # 20 days out → still pending
      end

      it 'filters by vencimiento (due within N days)' do
        get accounts_receivable_path(due_within: '15')
        expect(response.body).to include('Acme Corp')   # due in 10 days → in range
        expect(response.body).not_to include('Beta SA') # due in 20 days → out of range
      end

      it 'labels the sale-remaining column "Saldo total (USD)" and has no subtotal footer' do
        get accounts_receivable_path(q: 'Acme')
        expect(response.body).to include('Saldo total (USD)')
        expect(response.body).not_to include('ar-total-value')
      end
    end

    # -------------------------------------------------------------------------
    # CSV export (respects the active filters)
    # -------------------------------------------------------------------------
    context 'CSV export' do
      before { login_as(admin_user) }

      let(:acme)      { create(:client, :ruc_client, full_name: 'Acme Corp') }
      let(:beta)      { create(:client, :ruc_client, full_name: 'Beta SA') }
      let(:acme_sale) { create(:sale, :venta, client: acme, correlative: 'VTA-AAA01') }
      let(:beta_sale) { create(:sale, :venta, client: beta, correlative: 'VTA-BBB01') }

      let!(:acme_inst) do
        create(:installment, sale: acme_sale, status: 'pendiente',
                             due_date: Date.new(2026, 7, 10), amount_usd: 100, balance_usd: 100)
      end
      let!(:beta_inst) do
        create(:installment, sale: beta_sale, status: 'pendiente',
                             due_date: 20.days.from_now, amount_usd: 200, balance_usd: 200)
      end

      it 'exports outstanding installments as CSV with headers and rows' do
        get accounts_receivable_path(format: :csv)

        expect(response.media_type).to eq('text/csv')
        expect(response.body).to include('Cliente,Venta,N° de cuota,C. Vencidas,Cuota actual (USD),Saldo total (USD),Vencimiento,Estado')
        expect(response.body).to include('Acme Corp')
        expect(response.body).to include('VTA-AAA01')
        expect(response.body).to include('10/07/2026')
      end

      it 'respects the active filters' do
        get accounts_receivable_path(format: :csv, q: 'Acme')

        expect(response.body).to include('Acme Corp')
        expect(response.body).not_to include('Beta SA')
      end
    end

    # -------------------------------------------------------------------------
    # PDF export (pending/overdue invoices report)
    # -------------------------------------------------------------------------
    context 'PDF export' do
      before { login_as(admin_user) }

      let(:acme)      { create(:client, :ruc_client, full_name: 'Acme Corp') }
      let(:acme_sale) { create(:sale, :venta, client: acme, correlative: 'VTA-AAA01') }
      let!(:acme_inst) do
        create(:installment, sale: acme_sale, status: 'pendiente',
                             due_date: 5.days.ago, amount_usd: 100, balance_usd: 100)
      end

      it 'exports a PDF named after the report' do
        get accounts_receivable_path(format: :pdf)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('application/pdf')
        expect(response.body).to start_with('%PDF')
        expect(response.headers['Content-Disposition']).to include('facturas-pendientes')
      end
    end

    # -------------------------------------------------------------------------
    # AR-01: unauthenticated access is blocked
    # -------------------------------------------------------------------------
    context 'when unauthenticated' do
      it 'redirects to login (authenticate_user! guard — authn before authz)' do
        get accounts_receivable_path
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
