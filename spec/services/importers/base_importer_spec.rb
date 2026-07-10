require 'rails_helper'

RSpec.describe Importers::BaseImporter do
  # A minimal concrete subclass used to test the base class in isolation.
  # It just calls add_created for every row (no real DB work).
  let(:concrete_class) do
    Class.new(described_class) do
      def process_row(hash, fila, report)
        report.add_created(fila: fila)
      end
    end
  end

  let(:fixtures) { Rails.root.join('spec', 'fixtures', 'files') }

  describe '.call' do
    it 'returns a Result with an ImportReport on success' do
      path   = fixtures.join('products_valid.csv').to_s
      result = concrete_class.call(path, content_type: 'text/csv')
      expect(result.success?).to be true
      expect(result.record).to be_a(ImportReport)
    end

    it 'delegates row processing to subclass and counts created rows' do
      path   = fixtures.join('products_valid.csv').to_s
      result = concrete_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(3)
      expect(result.record.error_count).to eq(0)
    end

    it 'returns a failure Result when the file is rejected by SpreadsheetReader' do
      path = '/tmp/fake_test.txt'
      File.write(path, 'garbage')
      result = concrete_class.call(path, content_type: 'text/plain')
      expect(result.success?).to be false
      expect(result.errors.first).to match(/CSV|xlsx|Excel/i)
      File.delete(path) rescue nil
    end

    it 'returns a failure Result when file exceeds the 500-row cap' do
      path   = fixtures.join('products_over_cap.csv').to_s
      result = concrete_class.call(path, content_type: 'text/csv')
      expect(result.success?).to be false
      expect(result.errors.first).to match(/500/)
    end
  end

  describe '#call (instance method via .call)' do
    it 'passes a 1-based fila number to process_row' do
      path  = fixtures.join('products_valid.csv').to_s
      filas = []
      klass = Class.new(described_class) do
        define_method(:process_row) { |_hash, fila, _report| filas << fila }
      end
      klass.call(path, content_type: 'text/csv')
      expect(filas).to eq([ 1, 2, 3 ])
    end
  end

  # -------------------------------------------------------------------------
  # Per-row rescue (FIX 2 — reliability)
  # A process_row that raises on one row must NOT abort the whole import.
  # The failing row is recorded as :invalid; other rows still process.
  # -------------------------------------------------------------------------
  describe 'per-row error rescue' do
    let(:exploding_class) do
      Class.new(described_class) do
        # Raises on fila 2 (the second data row), succeeds on all others.
        def process_row(hash, fila, report)
          raise StandardError, 'kaboom' if fila == 2
          report.add_created(fila: fila)
        end
      end
    end

    it 'does not propagate the exception — import completes' do
      path = fixtures.join('products_valid.csv').to_s  # 3 data rows
      expect {
        exploding_class.call(path, content_type: 'text/csv')
      }.not_to raise_error
    end

    it 'returns a success Result (file-level success, row-level partial)' do
      path   = fixtures.join('products_valid.csv').to_s
      result = exploding_class.call(path, content_type: 'text/csv')
      expect(result.success?).to be true
    end

    it 'records the exploding row as :invalid with a Spanish error message' do
      path   = fixtures.join('products_valid.csv').to_s
      result = exploding_class.call(path, content_type: 'text/csv')
      report = result.record
      failed_rows = report.rows.select { |r| r[:status] == :invalid }
      expect(failed_rows.size).to eq(1)
      expect(failed_rows.first[:fila]).to eq(2)
      expect(failed_rows.first[:errores].first).to include('inesperado')
    end

    it 'continues processing the remaining rows after the error' do
      path   = fixtures.join('products_valid.csv').to_s
      result = exploding_class.call(path, content_type: 'text/csv')
      report = result.record
      created_rows = report.rows.select { |r| r[:status] == :created }
      expect(created_rows.map { |r| r[:fila] }).to eq([ 1, 3 ])
    end

    it 'rescues ActiveRecord::RecordNotUnique the same way as StandardError' do
      klass = Class.new(described_class) do
        def process_row(hash, fila, report)
          raise ActiveRecord::RecordNotUnique, 'duplicate key value violates unique constraint' if fila == 1
          report.add_created(fila: fila)
        end
      end
      path   = fixtures.join('products_valid.csv').to_s
      result = klass.call(path, content_type: 'text/csv')
      expect(result.success?).to be true
      report = result.record
      expect(report.rows.select { |r| r[:status] == :invalid }.first[:fila]).to eq(1)
      expect(report.rows.select { |r| r[:status] == :created }.map { |r| r[:fila] }).to eq([ 2, 3 ])
    end
  end
end
