require 'rails_helper'

# Tests the cotizacion-to-venta conversion flow.
# The conversion uses SaleCreationService.convert(cotizacion, params).
# It reuses the shared apply_venta_effects! logic (stock gate + decrement + installments).
RSpec.describe 'SaleCreationService.convert (cotizacion to venta)', type: :service do
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }
  let(:product_a) { create(:product, stock: 50, base_price_usd: 10.00, warehouse: warehouse) }
  let(:product_b) { create(:product, stock: 30, base_price_usd: 5.00,  warehouse: warehouse) }

  # A cotizacion with two line items
  let(:cotizacion) do
    sale = create(:sale, client: client, warehouse: warehouse,
                  document_type: 'cotizacion', status: 'confirmada',
                  subtotal_usd: 250.00, total_usd: 250.00)
    create(:sale_item, sale: sale, product: product_a, quantity: 20,
           unit_price_usd: 10.00, line_total_usd: 200.00)
    create(:sale_item, sale: sale, product: product_b, quantity: 10,
           unit_price_usd: 5.00, line_total_usd: 50.00)
    sale
  end

  let(:conversion_params) do
    { num_installments: 2, interval_days: 30 }
  end

  # ---------------------------------------------------------------------------
  # 1. Successful conversion
  # ---------------------------------------------------------------------------
  describe 'successful conversion with sufficient stock' do
    before { cotizacion }  # ensure cotizacion + items are persisted

    it 'creates a new venta record' do
      expect {
        SaleCreationService.convert(cotizacion, conversion_params)
      }.to change(Sale, :count).by(1)
    end

    it 'creates the venta with correct attributes' do
      result = SaleCreationService.convert(cotizacion, conversion_params)

      expect(result.success?).to be true
      venta = result.sale
      expect(venta.document_type).to eq('venta')
      expect(venta.status).to eq('confirmada')
      expect(venta.correlative).to match(/\AVTA-\d{5}\z/)
      expect(venta.total_usd).to eq(250.00)
    end

    it 'records the source cotizacion linkage on the new venta' do
      result = SaleCreationService.convert(cotizacion, conversion_params)

      expect(result.sale.source_cotizacion_id).to eq(cotizacion.id)
    end

    it 'decrements stock for each product' do
      stock_a_before = product_a.stock  # 50
      stock_b_before = product_b.stock  # 30

      SaleCreationService.convert(cotizacion, conversion_params)

      expect(product_a.reload.stock).to eq(stock_a_before - 20)
      expect(product_b.reload.stock).to eq(stock_b_before - 10)
    end

    it 'generates installments for the new venta' do
      result = SaleCreationService.convert(cotizacion, conversion_params)

      installments = result.sale.installments
      expect(installments.count).to eq(2)
      expect(installments.pluck(:amount_usd).map(&:to_d).sum).to eq(BigDecimal('250.00'))
    end

    it 'does not modify the original cotizacion' do
      SaleCreationService.convert(cotizacion, conversion_params)

      cotizacion.reload
      expect(cotizacion.document_type).to eq('cotizacion')
      expect(cotizacion.status).to eq('confirmada')
      expect(cotizacion.discarded_at).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Conversion blocked by insufficient stock
  # ---------------------------------------------------------------------------
  describe 'conversion blocked by insufficient stock' do
    let(:low_stock_product) { create(:product, stock: 0, base_price_usd: 10.00, warehouse: warehouse) }

    let(:cotizacion_with_low_stock) do
      sale = create(:sale, client: client, warehouse: warehouse,
                    document_type: 'cotizacion', status: 'confirmada',
                    subtotal_usd: 100.00, total_usd: 100.00)
      create(:sale_item, sale: sale, product: low_stock_product, quantity: 5,
             unit_price_usd: 10.00, line_total_usd: 50.00)
      sale
    end

    it 'returns failure Result' do
      result = SaleCreationService.convert(cotizacion_with_low_stock, conversion_params)
      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
    end

    it 'does not create a venta' do
      # Force cotizacion_with_low_stock to be created before taking the count baseline
      cotizacion_with_low_stock
      initial_count = Sale.count

      SaleCreationService.convert(cotizacion_with_low_stock, conversion_params)

      expect(Sale.count).to eq(initial_count)
    end

    it 'leaves stock unchanged' do
      SaleCreationService.convert(cotizacion_with_low_stock, conversion_params)
      expect(low_stock_product.reload.stock).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Already-converted cotizacion rejected
  # ---------------------------------------------------------------------------
  describe 'converting an already-converted cotizacion' do
    before do
      cotizacion
      # Perform the first conversion
      SaleCreationService.convert(cotizacion, conversion_params)
    end

    it 'returns failure Result' do
      result = SaleCreationService.convert(cotizacion, conversion_params)
      expect(result.success?).to be false
      expect(result.errors.first).to include('already been converted')
    end

    it 'does not create another venta' do
      sale_count_before = Sale.count

      SaleCreationService.convert(cotizacion, conversion_params)

      expect(Sale.count).to eq(sale_count_before)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Re-converting after the prior venta was annulled
  # ---------------------------------------------------------------------------
  # The already-converted guard must only count LIVE (kept) ventas. When the
  # converted venta is annulled it is soft-deleted (discarded_at set), which
  # frees the cotizacion so it can be converted again.
  describe 'converting a cotizacion whose prior venta was annulled' do
    before do
      cotizacion
      first = SaleCreationService.convert(cotizacion, conversion_params)
      SaleAnnulmentService.call(first.sale, nil)
    end

    it 'allows re-conversion' do
      result = SaleCreationService.convert(cotizacion, conversion_params)

      expect(result.success?).to be true
      expect(result.sale.source_cotizacion_id).to eq(cotizacion.id)
    end

    it 'creates a new venta' do
      expect {
        SaleCreationService.convert(cotizacion, conversion_params)
      }.to change(Sale.kept.where(document_type: 'venta'), :count).by(1)
    end
  end
end
