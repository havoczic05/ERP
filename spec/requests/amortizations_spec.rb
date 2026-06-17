require 'rails_helper'

RSpec.describe 'Amortizations', type: :request do
  # ---------------------------------------------------------------------------
  # Shared seam: inject current_user via ApplicationController#current_user=
  # ---------------------------------------------------------------------------
  let(:admin_user)  { create(:user, :administrador) }
  let(:vendor_user) { create(:user, :vendedor) }

  let(:sale)        { create(:sale, :venta, :with_items) }
  let(:installment) do
    create(:installment, sale: sale, amount_usd: 500.00, balance_usd: 500.00)
  end

  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  def amortization_params(amount: '200.00', notes: nil)
    { amortization: { amount_usd: amount, notes: notes } }
  end

  # ---------------------------------------------------------------------------
  # AR-06: admin can record an amortization
  # ---------------------------------------------------------------------------
  describe 'POST /installments/:installment_id/amortizations (admin — success)' do
    before { login_as(admin_user) }

    it 'creates an Amortization and redirects to accounts_receivable' do
      expect {
        post installment_amortizations_path(installment),
             params: amortization_params(amount: '200.00')
      }.to change(Amortization, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response.location).to include('/accounts_receivable')
      expect(flash[:notice]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # AR-06: vendedor can record an amortization
  # ---------------------------------------------------------------------------
  describe 'POST /installments/:installment_id/amortizations (vendedor — success)' do
    before { login_as(vendor_user) }

    it 'creates an Amortization and redirects' do
      expect {
        post installment_amortizations_path(installment),
             params: amortization_params(amount: '100.00')
      }.to change(Amortization, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(flash[:notice]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # AR-04: overpayment is rejected — balance unchanged, alert shown
  # ---------------------------------------------------------------------------
  describe 'POST /installments/:installment_id/amortizations (overpayment)' do
    before { login_as(admin_user) }

    it 'does not create an Amortization and shows alert' do
      original_balance = installment.balance_usd

      expect {
        post installment_amortizations_path(installment),
             params: amortization_params(amount: '9999.00')
      }.not_to change(Amortization, :count)

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
      expect(installment.reload.balance_usd).to eq(original_balance)
    end
  end

  # ---------------------------------------------------------------------------
  # AR-05: zero amount is rejected
  # ---------------------------------------------------------------------------
  describe 'POST /installments/:installment_id/amortizations (zero amount)' do
    before { login_as(admin_user) }

    it 'does not create an Amortization and shows alert' do
      expect {
        post installment_amortizations_path(installment),
             params: amortization_params(amount: '0')
      }.not_to change(Amortization, :count)

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # AR-06: unauthenticated POST is forbidden
  # ---------------------------------------------------------------------------
  describe 'POST /installments/:installment_id/amortizations (unauthenticated)' do
    it 'returns 403 Forbidden when no user is logged in' do
      post installment_amortizations_path(installment),
           params: amortization_params(amount: '100.00')

      expect(response).to have_http_status(:forbidden)
    end
  end
end
