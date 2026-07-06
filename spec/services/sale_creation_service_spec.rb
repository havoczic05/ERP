require 'rails_helper'

RSpec.describe SaleCreationService, type: :service do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }

  # Build a valid params hash for the service
  def sale_params(document_type:, items:, num_installments: 1, interval_days: 30, **extra)
    {
      client_id:        client.id,
      warehouse_id:     warehouse.id,
      document_type:    document_type,
      num_installments: num_installments,
      interval_days:    interval_days,
      notes:            nil,
      items:            items
    }.merge(extra)
  end

  def item_attrs(product:, quantity:, unit_price: nil)
    { product_id: product.id, quantity: quantity, unit_price_usd: unit_price || product.base_price_usd }
  end

  # ---------------------------------------------------------------------------
  # 1. Sufficient stock — venta created, stock decremented
  # ---------------------------------------------------------------------------
  describe 'venta with sufficient stock (happy path)' do
    it 'persists the sale and decrements product stock' do
      product = create(:product, stock: 50, base_price_usd: 10.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 5, unit_price: 10.00) ],
        num_installments: 1,
        interval_days: 30
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      expect(result.sale).to be_persisted
      expect(result.sale.document_type).to eq('venta')
      expect(result.sale.status).to eq('confirmada')
      expect(result.sale.total_usd).to eq(50.00)
      expect(product.reload.stock).to eq(45)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Oversell blocked — full rollback, no side effects
  # ---------------------------------------------------------------------------
  describe 'venta with insufficient stock' do
    it 'returns failure, does not persist sale, stock unchanged' do
      product = create(:product, stock: 10, base_price_usd: 5.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 20, unit_price: 5.00) ]
      )

      result = described_class.call(params)

      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
      expect(Sale.count).to eq(0)
      expect(product.reload.stock).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Cotizacion bypasses stock gate — stock unchanged even with qty > stock
  # ---------------------------------------------------------------------------
  describe 'cotizacion bypasses stock gate' do
    it 'persists the cotizacion even when qty > stock, stock not decremented' do
      product = create(:product, stock: 5, base_price_usd: 10.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'cotizacion',
        items: [ item_attrs(product: product, quantity: 100, unit_price: 10.00) ]
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      expect(result.sale).to be_persisted
      expect(result.sale.document_type).to eq('cotizacion')
      expect(product.reload.stock).to eq(5)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Partial oversell — full rollback (both products unchanged)
  # ---------------------------------------------------------------------------
  describe 'partial oversell triggers full rollback' do
    it 'leaves both products unchanged when one line exceeds stock' do
      product_a = create(:product, stock: 100, base_price_usd: 5.00, warehouse: warehouse)
      product_b = create(:product, stock: 5,   base_price_usd: 5.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [
          item_attrs(product: product_a, quantity: 10,  unit_price: 5.00),
          item_attrs(product: product_b, quantity: 10,  unit_price: 5.00)  # over stock
        ]
      )

      result = described_class.call(params)

      expect(result.success?).to be false
      expect(product_a.reload.stock).to eq(100)
      expect(product_b.reload.stock).to eq(5)
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Correlative format
  # ---------------------------------------------------------------------------
  describe 'correlative format' do
    it 'assigns VTA-##### for venta' do
      product = create(:product, stock: 50, warehouse: warehouse)
      params = sale_params(document_type: 'venta', items: [ item_attrs(product: product, quantity: 1) ])
      result = described_class.call(params)
      expect(result.sale.correlative).to match(/\AVTA-\d{5}\z/)
    end

    it 'assigns COT-##### for cotizacion' do
      product = create(:product, stock: 50, warehouse: warehouse)
      params = sale_params(document_type: 'cotizacion', items: [ item_attrs(product: product, quantity: 1) ])
      result = described_class.call(params)
      expect(result.sale.correlative).to match(/\ACOT-\d{5}\z/)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Correlative collision — RecordNotUnique rescued and retried
  # ---------------------------------------------------------------------------
  describe 'correlative collision retry' do
    it 'retries on RecordNotUnique and persists the sale with the next correlative' do
      product = create(:product, stock: 50, warehouse: warehouse)

      call_count = 0
      original_method = SaleCreationService.instance_method(:generate_correlative)

      allow_any_instance_of(SaleCreationService).to receive(:generate_correlative) do |instance, document_type|
        call_count += 1
        correlative = original_method.bind_call(instance, document_type)
        raise ActiveRecord::RecordNotUnique, 'duplicate correlative' if call_count == 1
        correlative
      end

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 1) ]
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      expect(result.sale).to be_persisted
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Totals computed correctly
  # ---------------------------------------------------------------------------
  describe 'total computation' do
    it 'computes subtotal, tax=0, total correctly for multiple line items' do
      product_a = create(:product, stock: 100, base_price_usd: 10.00, warehouse: warehouse)
      product_b = create(:product, stock: 100, base_price_usd: 5.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [
          item_attrs(product: product_a, quantity: 3, unit_price: 10.00),  # 30.00
          item_attrs(product: product_b, quantity: 4, unit_price: 5.00)    # 20.00
        ]
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      sale = result.sale
      expect(sale.subtotal_usd).to eq(50.00)
      expect(sale.tax_usd).to eq(0.00)
      expect(sale.total_usd).to eq(50.00)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. N=1 installment
  # ---------------------------------------------------------------------------
  describe 'N=1 installment' do
    it 'creates exactly one installment with full amount' do
      product = create(:product, stock: 50, base_price_usd: 150.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 1, unit_price: 150.00) ],
        num_installments: 1,
        interval_days: 30
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      installments = result.sale.installments
      expect(installments.count).to eq(1)
      expect(installments.first.amount_usd).to eq(150.00)
      expect(installments.first.status).to eq('pendiente')
      expect(installments.first.due_date).to eq(Date.today + 30)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. N=3 non-divisible — last absorbs remainder, SUM == total
  # ---------------------------------------------------------------------------
  describe 'N=3 with non-divisible total' do
    it 'splits 100.00 into [33.33, 33.33, 33.34], SUM==100.00' do
      product = create(:product, stock: 50, base_price_usd: 100.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 1, unit_price: 100.00) ],
        num_installments: 3,
        interval_days: 30
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      amounts = result.sale.installments.order(:installment_number).pluck(:amount_usd).map { |a| a.to_d }
      expect(amounts).to eq([ BigDecimal('33.33'), BigDecimal('33.33'), BigDecimal('33.34') ])
      expect(amounts.sum).to eq(BigDecimal('100.00'))
    end
  end

  # ---------------------------------------------------------------------------
  # 10. N=3 divisible — equal installments
  # ---------------------------------------------------------------------------
  describe 'N=3 with divisible total' do
    it 'splits 99.00 into three equal installments of 33.00' do
      product = create(:product, stock: 50, base_price_usd: 99.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 1, unit_price: 99.00) ],
        num_installments: 3,
        interval_days: 30
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      amounts = result.sale.installments.order(:installment_number).pluck(:amount_usd).map { |a| a.to_d }
      expect(amounts).to all(eq(BigDecimal('33.00')))
      expect(amounts.sum).to eq(BigDecimal('99.00'))
    end
  end

  # ---------------------------------------------------------------------------
  # 11. Cotizacion — no installments generated
  # ---------------------------------------------------------------------------
  describe 'cotizacion does not generate installments' do
    it 'creates zero installment records for a cotizacion' do
      product = create(:product, stock: 50, base_price_usd: 50.00, warehouse: warehouse)

      params = sale_params(
        document_type: 'cotizacion',
        items: [ item_attrs(product: product, quantity: 1, unit_price: 50.00) ],
        num_installments: 2,
        interval_days: 30
      )

      result = described_class.call(params)

      expect(result.success?).to be true
      expect(result.sale.installments.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Zero line items rejected
  # ---------------------------------------------------------------------------
  describe 'zero line items rejected' do
    it 'returns failure when no items are provided' do
      params = sale_params(document_type: 'venta', items: [])

      result = described_class.call(params)

      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 13. Quantity <= 0 rejected
  # ---------------------------------------------------------------------------
  describe 'quantity <= 0 rejected' do
    it 'returns failure when item quantity is zero' do
      product = create(:product, stock: 50, warehouse: warehouse)
      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 0) ]
      )
      result = described_class.call(params)
      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end

    it 'returns failure when item quantity is negative' do
      product = create(:product, stock: 50, warehouse: warehouse)
      params = sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: -1) ]
      )
      result = described_class.call(params)
      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 14. Non-existent product rejected
  # ---------------------------------------------------------------------------
  describe 'non-existent product rejected' do
    it 'returns failure for a product_id that does not exist' do
      params = sale_params(
        document_type: 'venta',
        items: [ { product_id: 999_999, quantity: 1, unit_price_usd: 10.00 } ]
      )
      result = described_class.call(params)
      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 15. Explicit installment plan (editable cuotas) — additive path
  #     When the caller supplies installments[] (date + amount per row) they are
  #     persisted verbatim, provided SUM == total and count is within 1..MAX.
  #     When absent/empty, the auto-generation path (tests 8-10) is unchanged.
  # ---------------------------------------------------------------------------
  describe 'explicit installment plan' do
    let(:product) { create(:product, stock: 50, base_price_usd: 100.00, warehouse: warehouse) }

    def explicit_params(installments:, document_type: 'venta', items: nil)
      items ||= [ item_attrs(product: product, quantity: 1, unit_price: 100.00) ]
      sale_params(document_type: document_type, items: items, installments: installments)
    end

    it 'persists the exact dates and amounts when the sum matches the total' do
      installments = [
        { due_date: '2026-08-01', amount_usd: '40.00' },
        { due_date: '2026-09-01', amount_usd: '35.00' },
        { due_date: '2026-10-01', amount_usd: '25.00' }
      ]

      result = described_class.call(explicit_params(installments: installments))

      expect(result.success?).to be true
      rows = result.sale.installments.order(:installment_number)
      expect(rows.pluck(:amount_usd).map(&:to_d))
        .to eq([ BigDecimal('40.00'), BigDecimal('35.00'), BigDecimal('25.00') ])
      expect(rows.pluck(:balance_usd).map(&:to_d))
        .to eq([ BigDecimal('40.00'), BigDecimal('35.00'), BigDecimal('25.00') ])
      expect(rows.pluck(:due_date))
        .to eq([ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1) ])
      expect(rows.pluck(:status).uniq).to eq([ 'pendiente' ])
    end

    it 'rejects the sale when the installment sum does not equal the total' do
      installments = [
        { due_date: '2026-08-01', amount_usd: '40.00' },
        { due_date: '2026-09-01', amount_usd: '40.00' } # 80 != 100
      ]

      result = described_class.call(explicit_params(installments: installments))

      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
      expect(Sale.count).to eq(0)
    end

    it 'rejects more than the maximum allowed installments' do
      installments = (1..5).map { |m| { due_date: format('2026-0%d-01', m), amount_usd: '20.00' } } # 5 x 20 = 100

      result = described_class.call(explicit_params(installments: installments))

      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end

    it 'rejects an installment with a blank due date' do
      installments = [ { due_date: '', amount_usd: '100.00' } ]

      result = described_class.call(explicit_params(installments: installments))

      expect(result.success?).to be false
      expect(Sale.count).to eq(0)
    end

    it 'ignores an empty installments array and falls back to auto-generation' do
      result = described_class.call(explicit_params(installments: []))

      expect(result.success?).to be true
      expect(result.sale.installments.count).to eq(1)
      expect(result.sale.installments.first.amount_usd).to eq(BigDecimal('100.00'))
    end

    it 'does not generate installments for a cotizacion even when supplied' do
      installments = [ { due_date: '2026-08-01', amount_usd: '100.00' } ]

      result = described_class.call(
        explicit_params(installments: installments, document_type: 'cotizacion')
      )

      expect(result.success?).to be true
      expect(result.sale.installments.count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # source_cotizacion_id — creating a venta linked to its originating cotizacion
  # (used by the two-step convert flow, which builds the venta from an editable
  # form rather than copying the cotizacion verbatim).
  # ---------------------------------------------------------------------------
  describe 'venta linked to a source cotizacion' do
    let(:product) { create(:product, stock: 50, base_price_usd: 10.00, warehouse: warehouse) }
    let(:cotizacion) do
      create(:sale, client: client, warehouse: warehouse,
             document_type: 'cotizacion', status: 'confirmada',
             subtotal_usd: 10.00, total_usd: 10.00)
    end

    def linked_params(**extra)
      sale_params(
        document_type: 'venta',
        items: [ item_attrs(product: product, quantity: 1, unit_price: 10.00) ],
        source_cotizacion_id: cotizacion.id,
        **extra
      )
    end

    it 'records the source cotizacion linkage on the new venta' do
      result = described_class.call(linked_params)

      expect(result.success?).to be true
      expect(result.sale.source_cotizacion_id).to eq(cotizacion.id)
    end

    it 'rejects when a live venta already references the cotizacion' do
      described_class.call(linked_params)

      result = described_class.call(linked_params)

      expect(result.success?).to be false
      expect(result.errors.first).to include('already been converted')
    end

    it 'allows creation again after the prior linked venta was annulled' do
      first = described_class.call(linked_params)
      SaleAnnulmentService.call(first.sale, nil)

      result = described_class.call(linked_params)

      expect(result.success?).to be true
      expect(result.sale.source_cotizacion_id).to eq(cotizacion.id)
    end
  end
end
