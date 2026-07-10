require 'rails_helper'

RSpec.describe ImportReport do
  subject(:report) { described_class.new }

  describe '#initialize' do
    it 'starts with zero created_count' do
      expect(report.created_count).to eq(0)
    end

    it 'starts with zero error_count' do
      expect(report.error_count).to eq(0)
    end

    it 'starts with an empty rows array' do
      expect(report.rows).to eq([])
    end
  end

  describe '#add_created' do
    it 'increments created_count' do
      report.add_created(fila: 1)
      expect(report.created_count).to eq(1)
    end

    it 'appends a row with status :created' do
      report.add_created(fila: 3)
      expect(report.rows.last).to eq({ fila: 3, status: :created, errores: [] })
    end

    it 'increments created_count cumulatively' do
      report.add_created(fila: 1)
      report.add_created(fila: 2)
      expect(report.created_count).to eq(2)
    end
  end

  describe '#add_duplicate' do
    it 'increments error_count' do
      report.add_duplicate(fila: 2, razon: 'SKU duplicado')
      expect(report.error_count).to eq(1)
    end

    it 'appends a row with status :duplicate' do
      report.add_duplicate(fila: 2, razon: 'SKU duplicado')
      expect(report.rows.last).to eq({ fila: 2, status: :duplicate, errores: [ 'SKU duplicado' ] })
    end
  end

  describe '#add_invalid' do
    it 'increments error_count' do
      report.add_invalid(fila: 5, errores: [ 'Nombre no puede estar en blanco' ])
      expect(report.error_count).to eq(1)
    end

    it 'appends a row with status :invalid' do
      report.add_invalid(fila: 5, errores: [ 'Nombre no puede estar en blanco' ])
      expect(report.rows.last).to eq({ fila: 5, status: :invalid, errores: [ 'Nombre no puede estar en blanco' ] })
    end

    it 'stores multiple error messages' do
      report.add_invalid(fila: 7, errores: [ 'err1', 'err2' ])
      expect(report.rows.last[:errores]).to eq([ 'err1', 'err2' ])
    end
  end

  describe 'mixed scenario' do
    it 'correctly tallies created and error counts across mixed rows' do
      report.add_created(fila: 1)
      report.add_invalid(fila: 2, errores: [ 'error' ])
      report.add_duplicate(fila: 3, razon: 'SKU duplicado')
      report.add_created(fila: 4)

      expect(report.created_count).to eq(2)
      expect(report.error_count).to eq(2)
      expect(report.rows.size).to eq(4)
    end
  end
end
