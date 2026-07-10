require 'rails_helper'

RSpec.describe SpreadsheetReader do
  let(:fixtures) { Rails.root.join('spec', 'fixtures', 'files') }

  # Helper: collect all yielded hashes from a reader call
  def read_all(path, content_type: 'text/csv')
    rows = []
    described_class.call(path, content_type: content_type) do |hash, fila|
      rows << { hash: hash, fila: fila }
    end
    rows
  end

  # -------------------------------------------------------------------------
  # Valid CSV
  # -------------------------------------------------------------------------
  describe 'CSV reading' do
    let(:path) { fixtures.join('products_valid.csv').to_s }

    it 'yields header→value hashes for each data row' do
      rows = read_all(path)
      expect(rows.size).to eq(3)
      expect(rows.first[:hash]['SKU']).to eq('ABC001')
      expect(rows.first[:hash]['Nombre']).to eq('Producto Uno')
    end

    it 'assigns 1-based fila numbers starting at 1' do
      rows = read_all(path)
      expect(rows.map { |r| r[:fila] }).to eq([ 1, 2, 3 ])
    end

    it 'trims leading and trailing whitespace from string values' do
      rows = read_all(path)
      # Row 3 has "  Producto Tres  " and "  Almacén Sur  "
      expect(rows[2][:hash]['Nombre']).to eq('Producto Tres')
      expect(rows[2][:hash]['Almacén']).to eq('Almacén Sur')
    end

    it 'returns a success Result (no block argument used for success)' do
      result = described_class.call(path, content_type: 'text/csv') { |_, _| }
      expect(result.success?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # Valid XLSX
  # -------------------------------------------------------------------------
  describe 'XLSX reading' do
    let(:path) { fixtures.join('products_valid.xlsx').to_s }

    it 'yields header→value hashes for each data row' do
      rows = read_all(path, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(rows.size).to eq(2)
      expect(rows.first[:hash]['SKU']).to eq('XLS001')
    end

    it 'preserves numeric values (stock as integer-compatible, price as float)' do
      rows = read_all(path, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      # Stock is 15 (Numeric) — must stay Numeric (not crash), coercion preserves it
      expect(rows.first[:hash]['Stock']).to be_a(Numeric)
      expect(rows.first[:hash]['Stock'].to_i).to eq(15)
      expect(rows.first[:hash]['Precio base USD'].to_f).to eq(30.0)
    end

    it 'trims whitespace from string values' do
      rows = read_all(path, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(rows[1][:hash]['Nombre']).to eq('Producto Espacios')
    end

    it 'only reads the first sheet' do
      path2 = fixtures.join('two_sheets.xlsx').to_s
      rows = read_all(path2, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      # two_sheets.xlsx has 1 data row on sheet1 and 2 garbage rows on sheet2
      expect(rows.size).to eq(1)
      expect(rows.first[:hash]['SKU']).to eq('S001')
    end
  end

  # -------------------------------------------------------------------------
  # 500-row cap
  # -------------------------------------------------------------------------
  describe '500-row cap' do
    it 'rejects a file with 501 data rows and returns a failure Result' do
      path = fixtures.join('products_over_cap.csv').to_s
      result = nil
      block_called = false
      result = described_class.call(path, content_type: 'text/csv') { block_called = true }
      expect(result.success?).to be false
      expect(result.errors.first).to match(/500/)
      expect(block_called).to be false
    end

    it 'accepts a file with exactly 500 data rows' do
      path = fixtures.join('products_at_cap.csv').to_s
      count = 0
      result = described_class.call(path, content_type: 'text/csv') { |_, _| count += 1 }
      expect(result.success?).to be true
      expect(count).to eq(500)
    end
  end

  # -------------------------------------------------------------------------
  # Bad extension
  # -------------------------------------------------------------------------
  describe 'extension validation' do
    it 'rejects a .txt file and returns a failure Result with a Spanish message' do
      path = fixtures.join('logo.png').to_s.sub('.png', '.txt')
      # Create a dummy .txt file
      File.write(path, "hello")
      result = described_class.call(path, content_type: 'text/plain') { }
      expect(result.success?).to be false
      expect(result.errors.first).to match(/CSV|xlsx|Excel/i)
      File.delete(path) rescue nil
    end

    it 'rejects a .pdf extension regardless of content-type' do
      path = '/tmp/fake_import.pdf'
      File.write(path, '%PDF-fake')
      result = described_class.call(path, content_type: 'application/pdf') { }
      expect(result.success?).to be false
      expect(result.errors.first).to match(/CSV|xlsx|Excel/i)
      File.delete(path) rescue nil
    end
  end

  # -------------------------------------------------------------------------
  # Empty file / header-only file (FIX 1 — reliability)
  # -------------------------------------------------------------------------
  describe 'empty or header-only file' do
    it 'returns a failure Result with a Spanish message for a 0-byte CSV (does NOT raise)' do
      path = fixtures.join('empty.csv').to_s
      result = nil
      expect {
        result = described_class.call(path, content_type: 'text/csv') { |_, _| }
      }.not_to raise_error
      expect(result).not_to be_nil
      expect(result.success?).to be false
      expect(result.errors.first).to include('vacío')
    end

    it 'returns success with zero rows yielded for a header-only CSV (1 row, no data)' do
      path = '/tmp/header_only.csv'
      File.write(path, "SKU,Nombre,Marca\n")
      rows = []
      result = described_class.call(path, content_type: 'text/csv') { |h, _| rows << h }
      expect(result.success?).to be true
      expect(rows).to be_empty
      File.delete(path) rescue nil
    end
  end

  # -------------------------------------------------------------------------
  # Bad content-type
  # -------------------------------------------------------------------------
  describe 'content-type validation' do
    it 'rejects a .csv file with an unexpected content-type' do
      path = fixtures.join('products_valid.csv').to_s
      result = described_class.call(path, content_type: 'application/octet-stream') { }
      expect(result.success?).to be false
      expect(result.errors.first).to match(/CSV|xlsx|Excel/i)
    end

    it 'accepts application/vnd.ms-excel as a valid xlsx content-type' do
      path = fixtures.join('products_valid.xlsx').to_s
      rows = []
      result = described_class.call(path, content_type: 'application/vnd.ms-excel') { |h, _| rows << h }
      expect(result.success?).to be true
      expect(rows).not_to be_empty
    end
  end
end
