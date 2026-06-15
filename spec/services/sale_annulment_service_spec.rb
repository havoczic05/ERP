require 'rails_helper'

RSpec.describe SaleAnnulmentService, type: :service do
  # ---------------------------------------------------------------------------
  # Shared setup: a confirmed venta with two line items and two installments
  # ---------------------------------------------------------------------------
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }

  let(:product_a) { create(:product, stock: 100, base_price_usd: 10.00, warehouse: warehouse) }
  let(:product_b) { create(:product, stock: 200, base_price_usd: 5.00,  warehouse: warehouse) }

  let(:venta) do
    sale = create(:sale, :venta, client: client, warehouse: warehouse,
                  subtotal_usd: 100.00, tax_usd: 0.00, total_usd: 100.00)
    create(:sale_item, sale: sale, product: product_a, quantity: 10,
           unit_price_usd: 10.00, line_total_usd: 100.00)
    # Give product_b a sale item for the second-product scenario
    sale
  end

  # Two installments with balances for the happy-path test
  let(:installment_1) do
    create(:installment, sale: venta, installment_number: 1, amount_usd: 50.00, balance_usd: 50.00)
  end
  let(:installment_2) do
    create(:installment, sale: venta, installment_number: 2, amount_usd: 50.00, balance_usd: 50.00)
  end

  let(:admin_user) { build(:user, :administrador) }

  # ---------------------------------------------------------------------------
  # 1. Happy path — admin annuls a confirmed venta
  # ---------------------------------------------------------------------------
  describe 'admin annuls a confirmed venta' do
    before do
      # Force eager evaluation of all the lets to ensure DB records exist
      installment_1
      installment_2
    end

    it 'sets sale status=anulada and discarded_at' do
      result = SaleAnnulmentService.call(venta, admin_user)

      expect(result.success?).to be true
      venta.reload
      expect(venta.status).to eq('anulada')
      expect(venta.discarded_at).not_to be_nil
    end

    it 'restores product stock for each sale_item quantity' do
      stock_before = product_a.stock  # 100

      SaleAnnulmentService.call(venta, admin_user)

      expect(product_a.reload.stock).to eq(stock_before + 10)
    end

    it 'voids all installments (status=anulada, amount=0, balance=0)' do
      SaleAnnulmentService.call(venta, admin_user)

      [ installment_1, installment_2 ].each do |inst|
        inst.reload
        expect(inst.status).to eq('anulada')
        expect(inst.amount_usd).to eq(0.00)
        expect(inst.balance_usd).to eq(0.00)
      end
    end

    it 'creates a CreditNote with total_usd == sale.total_usd' do
      SaleAnnulmentService.call(venta, admin_user)

      credit_note = venta.reload.credit_note
      expect(credit_note).not_to be_nil
      expect(credit_note.total_usd).to eq(100.00)
      expect(credit_note.issued_at).not_to be_nil
    end

    it 'commits all changes atomically in a single transaction' do
      # Verify that after the call all side effects are committed together
      result = SaleAnnulmentService.call(venta, admin_user)

      expect(result.success?).to be true
      expect(CreditNote.count).to eq(1)
      expect(venta.reload.status).to eq('anulada')
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Idempotency — already-anulada sale rejected with no side effects
  # ---------------------------------------------------------------------------
  describe 'annulling an already-anulada sale' do
    let(:already_anulada) do
      create(:sale, :venta, :anulada, client: client, warehouse: warehouse,
             subtotal_usd: 50.00, total_usd: 50.00)
    end

    it 'returns failure Result' do
      result = SaleAnnulmentService.call(already_anulada, admin_user)
      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
    end

    it 'does not create a CreditNote' do
      expect {
        SaleAnnulmentService.call(already_anulada, admin_user)
      }.not_to change(CreditNote, :count)
    end

    it 'does not change the sale discarded_at' do
      original_discarded_at = already_anulada.discarded_at
      SaleAnnulmentService.call(already_anulada, admin_user)
      expect(already_anulada.reload.discarded_at).to be_within(1.second).of(original_discarded_at)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Rollback on CreditNote creation failure — no side effects
  # ---------------------------------------------------------------------------
  describe 'rollback when CreditNote creation fails' do
    before { installment_1 }

    it 'rolls back: sale status unchanged, stock unchanged, no CreditNote' do
      allow(CreditNote).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(CreditNote.new))

      stock_before = product_a.stock
      status_before = venta.status

      SaleAnnulmentService.call(venta, admin_user)

      expect(venta.reload.status).to eq(status_before)
      expect(product_a.reload.stock).to eq(stock_before)
      expect(CreditNote.count).to eq(0)
    end
  end
end
