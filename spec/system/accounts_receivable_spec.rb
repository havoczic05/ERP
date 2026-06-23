require 'rails_helper'

# System specs for AccountsReceivable index view (Slice 4, AR-01).
# Driver: rack_test (no Chrome/Chromium in this WSL2 environment).
# Assertions are server-rendered HTML only. No live-JS behaviors.

RSpec.describe 'AccountsReceivable index', type: :system do
  before { driven_by(:rack_test) }

  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(admin)
  end

  let(:sale)   { create(:sale, :venta, :with_items) }
  let(:client) { sale.client }

  it 'renders the page heading' do
    visit accounts_receivable_path
    expect(page).to have_content('Cuentas por Cobrar')
  end

  it 'lists a pending installment with client name and sale correlative' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: 10.days.from_now,
                          amount_usd: 400.00,
                          balance_usd: 400.00)

    visit accounts_receivable_path

    expect(page).to have_content(client.full_name)
    expect(page).to have_content(sale.correlative)
  end

  it 'does not show pagada installments' do
    create(:installment, sale: sale,
                          status: 'pagada',
                          due_date: 5.days.from_now,
                          amount_usd: 100.00,
                          balance_usd: 0.00)

    visit accounts_receivable_path

    expect(page).not_to have_content('Pagada')
  end

  it 'shows the Vencida badge for past-due installments' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: 1.day.ago,
                          amount_usd: 200.00,
                          balance_usd: 200.00)

    visit accounts_receivable_path

    # Target the badge element — the estado filter select also has a "Vencida" option.
    expect(page).to have_css('.badge--danger', text: 'Vencida')
  end

  it 'does not show Vencida badge for installments due today' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: Date.current,
                          amount_usd: 200.00,
                          balance_usd: 200.00)

    visit accounts_receivable_path

    expect(page).not_to have_css('.badge--danger')
  end

  it 'shows the "No hay cuotas pendientes." message when no records exist' do
    visit accounts_receivable_path
    expect(page).to have_content('No hay cuotas pendientes.')
  end

  it 'renders an inline payment form per installment row' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: 7.days.from_now,
                          amount_usd: 300.00,
                          balance_usd: 300.00)

    visit accounts_receivable_path

    expect(page).to have_button('Registrar pago')
    expect(page).to have_field('amortization[amount_usd]')
    expect(page).to have_field('amortization[notes]')
  end

  describe 'filters' do
    let(:acme)      { create(:client, :ruc_client, full_name: 'Acme Corp') }
    let(:beta)      { create(:client, :ruc_client, full_name: 'Beta SA') }
    let(:acme_sale) { create(:sale, :venta, client: acme, correlative: 'VTA-AAA01') }
    let(:beta_sale) { create(:sale, :venta, client: beta, correlative: 'VTA-BBB01') }

    before do
      create(:installment, sale: acme_sale, status: 'pendiente',
                           due_date: 3.days.from_now, amount_usd: 100, balance_usd: 100)
      create(:installment, sale: beta_sale, status: 'pendiente',
                           due_date: 25.days.from_now, amount_usd: 200, balance_usd: 200)
    end

    it 'filters by client name or correlative via q' do
      visit accounts_receivable_path
      fill_in 'q', with: 'Acme'
      click_button 'Filtrar'

      expect(page).to have_content('Acme Corp')
      expect(page).not_to have_content('Beta SA')
    end

    it 'filters by vencimiento within N days' do
      visit accounts_receivable_path
      select 'Próximos 5 días', from: 'due_within'
      click_button 'Filtrar'

      expect(page).to have_content('Acme Corp')   # due in 3 days
      expect(page).not_to have_content('Beta SA') # due in 25 days
    end

    it 'shows the outstanding subtotal aligned under the Saldo column' do
      visit accounts_receivable_path
      expect(page).to have_css('tfoot .ar-total-label', text: 'Saldo total')
      expect(page).to have_css('tfoot .ar-total-value')
    end

    it 'offers a CSV export link at the bottom-right of the table' do
      visit accounts_receivable_path
      expect(page).to have_css('.table-footer', text: 'Descargar Excel')
      expect(page.find_link('Descargar Excel')[:href]).to include('format=csv')
    end
  end
end
