require 'rails_helper'

RSpec.describe Importers::ClientImporter do
  # Build a temp CSV with ClientsController::CSV_HEADERS
  def write_csv(path, data_rows)
    require 'csv'
    CSV.open(path, 'w') do |csv|
      csv << [ 'Nombre completo', 'Tipo de documento', 'Número de documento',
               'Teléfono', 'Dirección', 'Distrito', 'Provincia', 'Departamento' ]
      data_rows.each { |row| csv << row }
    end
    path
  end

  let(:fixtures) { Rails.root.join('spec', 'fixtures', 'files') }

  describe 'successful creation' do
    it 'creates a Client and reports it as :created (RUC)' do
      path = write_csv('/tmp/import_clients_ruc.csv', [
        [ 'Empresa SAC', 'RUC', '20123456789', '999111222', 'Av. Lima 100', 'Miraflores', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.success?).to be true
      expect(result.record.created_count).to eq(1)
      expect(Client.kept.find_by(document_number: '20123456789')).to be_present
    end

    it 'creates a Client and reports it as :created (DNI)' do
      path = write_csv('/tmp/import_clients_dni.csv', [
        [ 'Juan Pérez', 'DNI', '12345678', '999333444', 'Jr. Cusco 200', 'Surco', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
      expect(Client.kept.find_by(document_number: '12345678')).to be_present
    end

    it 'accepts document_type case-insensitively (lowercase ruc)' do
      path = write_csv('/tmp/import_clients_lower_ruc.csv', [
        [ 'Corp ABC', 'ruc', '20999888777', '999000111', 'Av. X 1', 'Lince', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
    end

    it 'accepts document_type case-insensitively (mixed case Dni)' do
      path = write_csv('/tmp/import_clients_mixed_dni.csv', [
        [ 'María García', 'Dni', '87654321', '988000222', 'Av. Y 2', 'Surco', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
    end
  end

  describe 'duplicate detection' do
    let!(:existing_client) do
      create(:client, :ruc_client, document_number: '20111222333', full_name: 'Empresa Existente SAC',
             phone: '999000999')
    end

    it 'reports a kept duplicate (same document_number) as :duplicate' do
      count_before = Client.kept.count
      path = write_csv('/tmp/import_clients_dup.csv', [
        [ 'Otro Nombre', 'RUC', '20111222333', '999999999', 'Av. Z 3', 'Lima', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:status]).to eq(:duplicate)
      expect(result.record.rows.first[:errores]).to include(match(/documento.*duplicado|duplicado/i))
      expect(Client.kept.count).to eq(count_before)
    end

    it 'does NOT count a discarded client with the same document_number as duplicate' do
      existing_client.update!(discarded_at: Time.current)
      path = write_csv('/tmp/import_clients_disc_dup.csv', [
        [ 'Nueva Empresa SAC', 'RUC', '20111222333', '999999999', 'Av. Q 4', 'Lima', 'Lima', 'Lima' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(1)
    end
  end

  describe 'invalid rows' do
    it 'reports a row with blank Nombre completo as :invalid' do
      path = write_csv('/tmp/import_clients_blank_name.csv', [
        [ '', 'DNI', '12345678', '999000111', 'Dir', 'D', 'P', 'Dep' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:status]).to eq(:invalid)
      expect(result.record.rows.first[:errores].join).to match(/blanco/i)
    end

    it 'reports a RUC number with fewer than 11 digits as :invalid' do
      path = write_csv('/tmp/import_clients_short_ruc.csv', [
        [ 'Corp SAC', 'RUC', '2012345', '999000111', 'Dir', 'D', 'P', 'Dep' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:errores].join).to match(/11.*dígitos|RUC/i)
    end

    it 'reports a DNI number with fewer than 8 digits as :invalid' do
      path = write_csv('/tmp/import_clients_short_dni.csv', [
        [ 'Juan Pérez', 'DNI', '1234567', '999000111', 'Dir', 'D', 'P', 'Dep' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:errores].join).to match(/8.*dígitos|DNI/i)
    end

    it 'reports an unrecognized document_type as :invalid with a Spanish error' do
      path = write_csv('/tmp/import_clients_unknown_doc.csv', [
        [ 'Ana López', 'Pasaporte', '12345678', '999000111', 'Dir', 'D', 'P', 'Dep' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.error_count).to eq(1)
      expect(result.record.rows.first[:status]).to eq(:invalid)
      expect(result.record.rows.first[:errores].join).to match(/tipo.*documento.*no reconocido|no reconocido/i)
    end
  end

  describe 'partial save (no file-level transaction)' do
    it 'creates valid rows and reports invalid rows in the same file' do
      path = write_csv('/tmp/import_clients_mixed.csv', [
        [ 'Cliente Uno', 'DNI', '11111111', '999001001', 'Dir 1', 'D', 'P', 'Dep' ],
        [ '', 'DNI', '22222222', '999002002', 'Dir 2', 'D', 'P', 'Dep' ],  # blank name
        [ 'Cliente Tres', 'RUC', '20333444555', '999003003', 'Dir 3', 'D', 'P', 'Dep' ]
      ])
      result = described_class.call(path, content_type: 'text/csv')
      expect(result.record.created_count).to eq(2)
      expect(result.record.error_count).to eq(1)
      expect(Client.kept.where(document_number: %w[11111111 20333444555]).count).to eq(2)
      expect(Client.kept.find_by(document_number: '22222222')).to be_nil
    end
  end

  describe 'XLSX input' do
    it 'processes a valid xlsx file with clients' do
      path = fixtures.join('clients_valid.xlsx').to_s
      result = described_class.call(path, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(result.success?).to be true
      expect(result.record.created_count).to eq(1)
      expect(Client.kept.find_by(document_number: '20987654321')).to be_present
    end
  end
end
