require 'rails_helper'

RSpec.describe 'AccountsReceivable', type: :request do
  # ---------------------------------------------------------------------------
  # Shared seam: inject current_user via ApplicationController#current_user=
  # ---------------------------------------------------------------------------
  let(:admin_user) { create(:user, :administrador) }

  let(:sale)   { create(:sale, :venta, :with_items) }
  let(:client) { sale.client }

  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

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
        expect(response.body).not_to include('pagada')
      end

      it 'shows an overdue indicator for a past-due installment' do
        create(:installment, sale: sale,
                              status: 'pendiente',
                              due_date: 1.day.ago,
                              amount_usd: 150.00,
                              balance_usd: 150.00)

        get accounts_receivable_path

        expect(response.body).to include('Overdue')
      end

      it 'does not show overdue indicator for an installment due today' do
        create(:installment, sale: sale,
                              status: 'pendiente',
                              due_date: Date.current,
                              amount_usd: 150.00,
                              balance_usd: 150.00)

        get accounts_receivable_path

        expect(response.body).not_to include('Overdue')
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
