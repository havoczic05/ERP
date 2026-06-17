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
    expect(page).to have_content('Accounts Receivable')
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

    expect(page).not_to have_content('pagada')
  end

  it 'shows the Overdue badge for past-due installments' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: 1.day.ago,
                          amount_usd: 200.00,
                          balance_usd: 200.00)

    visit accounts_receivable_path

    expect(page).to have_content('Overdue')
  end

  it 'does not show Overdue badge for installments due today' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: Date.current,
                          amount_usd: 200.00,
                          balance_usd: 200.00)

    visit accounts_receivable_path

    expect(page).not_to have_content('Overdue')
  end

  it 'shows the "No pending installments." message when no records exist' do
    visit accounts_receivable_path
    expect(page).to have_content('No pending installments.')
  end

  it 'renders an inline payment form per installment row' do
    create(:installment, sale: sale,
                          status: 'pendiente',
                          due_date: 7.days.from_now,
                          amount_usd: 300.00,
                          balance_usd: 300.00)

    visit accounts_receivable_path

    expect(page).to have_button('Record Payment')
    expect(page).to have_field('amortization[amount_usd]')
  end
end
