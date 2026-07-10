require 'rails_helper'

RSpec.describe Importers::ProductImporter do
  let(:fixtures) { Rails.root.join('spec', 'fixtures', 'files') }

  # Build a temp CSV at a given path with given rows (after the header)
  def write_csv(path, data_rows)
    require 'csv'
    CSV.open(path, 'w') do |csv|
      csv << [ 'SKU', 'Nombre', 'Marca', 'Almacén', 'Stock', 'Precio base USD' ]
      data_rows.each { |row| csv << row }
    end
    path
  end

  let!(:warehouse) { create(:warehouse, name: 'Almacén Central') }

  describe 'successful creation' do
    it 'creates a Product and reports it as :created' do
      path = write_csv('/tmp/import_products_create.csv', [
        [ 'SKU-NEW1', 'Producto Nuevo', 'Marca A', 'Almacén Central', '10', '25.50' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.success?).to be true
      expect(result.record.created_count).to eq(1)
      expect(result.record.error_count).to eq(0)
      expect(Product.kept.find_by(sku: 'SKU-NEW1')).to be_present
    end

    it 'trims whitespace from SKU and name before saving' do
      path = write_csv('/tmp/import_products_trim.csv', [
        [ '  SKU-TRIM  ', '  Producto Trim  ', 'Marca B', 'Almacén Central', '5', '10.00' ]
      ])
      described_class.call(path, content_type: 'text/csv')
      expect(Product.kept.find_by(sku: 'SKU-TRIM')).to be_present
      expect(Product.kept.find_by(sku: 'SKU-TRIM').name).to eq('Producto Trim')
    end

    it 'resolves warehouse by trimmed, case-insensitive name' do
      path = write_csv('/tmp/import_products_case.csv', [
        [ 'SKU-CASE1', 'Prod Case', 'Marca', '  almacén central  ', '3', '5.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
      expect(Product.kept.find_by(sku: 'SKU-CASE1').warehouse).to eq(warehouse)
    end
  end

  describe 'duplicate detection' do
    let!(:existing_product) { create(:product, sku: 'SKU-DUP1', warehouse: warehouse) }

    it 'reports a kept duplicate as :duplicate and does not create a second record' do
      count_before = Product.kept.count
      path = write_csv('/tmp/import_products_dup.csv', [
        [ 'SKU-DUP1', 'Otro Nombre', 'Marca', 'Almacén Central', '5', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:status]).to eq(:duplicate)
      expect(result.record.rows.first[:errores]).to include(match(/SKU.*duplicado|duplicado.*SKU/i))
      expect(Product.kept.count).to eq(count_before)
    end

    it 'does NOT count a discarded product with the same SKU as duplicate' do
      existing_product.update!(discarded_at: Time.current)
      path = write_csv('/tmp/import_products_discarded_dup.csv', [
        [ 'SKU-DUP1', 'Producto Nuevo', 'Marca', 'Almacén Central', '5', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
      expect(result.record.error_count).to eq(0)
    end
  end

  describe 'invalid rows' do
    it 'reports a row with blank Nombre as :invalid with a Spanish error' do
      path = write_csv('/tmp/import_products_blank_name.csv', [
        [ 'SKU-INV1', '', 'Marca', 'Almacén Central', '5', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:status]).to eq(:invalid)
      expect(result.record.rows.first[:errores].join).to match(/blanco|nombre/i)
    end

    it 'reports a row with stock < 0 as :invalid' do
      path = write_csv('/tmp/import_products_neg_stock.csv', [
        [ 'SKU-NEG1', 'Prod', 'Marca', 'Almacén Central', '-1', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:errores].join).to match(/mayor|igual|0/i)
    end

    it 'reports a row with price <= 0 as :invalid' do
      path = write_csv('/tmp/import_products_zero_price.csv', [
        [ 'SKU-ZP1', 'Prod', 'Marca', 'Almacén Central', '5', '0' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:errores].join).to match(/mayor/i)
    end

    it 'reports a row with an unresolvable warehouse name as :invalid' do
      path = write_csv('/tmp/import_products_no_wh.csv', [
        [ 'SKU-NWH1', 'Prod', 'Marca', 'Bodega Inexistente', '5', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:errores].join).to match(/almacén.*encontrado|no encontrado/i)
    end
  end

  describe 'partial save (no file-level transaction)' do
    it 'creates valid rows and reports invalid rows, all in the same file' do
      path = write_csv('/tmp/import_products_mixed.csv', [
        [ 'SKU-MIX1', 'Valido Uno', 'Marca', 'Almacén Central', '10', '15.00' ],
        [ 'SKU-MIX2', '', 'Marca', 'Almacén Central', '5', '10.00' ],  # blank name
        [ 'SKU-MIX3', 'Valido Tres', 'Marca', 'Almacén Central', '3', '20.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(2)
      expect(result.record.error_count).to eq(1)
      expect(Product.kept.where(sku: %w[SKU-MIX1 SKU-MIX3]).count).to eq(2)
      expect(Product.kept.find_by(sku: 'SKU-MIX2')).to be_nil
    end

    it 'records the correct 1-based fila number in each row entry' do
      path = write_csv('/tmp/import_products_fila.csv', [
        [ 'SKU-F1', 'Prod F1', 'Marca', 'Almacén Central', '5', '10.00' ],
        [ 'SKU-F2', '', 'Marca', 'Almacén Central', '5', '10.00' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.rows[0][:fila]).to eq(1)
      expect(result.record.rows[1][:fila]).to eq(2)
    end
  end

  describe 'XLSX input' do
    it 'processes a valid xlsx file identically to csv' do
      path = fixtures.join('products_valid.xlsx').to_s
      # Ensure the warehouses referenced in the xlsx exist
      create(:warehouse, name: 'Almacén Norte')
      result = described_class.call(path, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(result.success?).to be true
      expect(result.record.created_count).to eq(2)
    end
  end
end
