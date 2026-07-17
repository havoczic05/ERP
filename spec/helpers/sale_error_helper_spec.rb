require 'rails_helper'

RSpec.describe SaleErrorHelper, type: :helper do
  describe '.classify' do
    let(:sale) { instance_double('Sale', errors: double(full_messages: [])) }

    it 'returns empty groups when errors is empty' do
      result = described_class.classify([], sale)
      expect(result).to eq(
        cliente: [],
        almacen: [],
        cuotas: [],
        general: []
      )
    end

    it 'buckets an error containing "cliente" into :cliente' do
      result = described_class.classify([ "El cliente no existe" ], sale)
      expect(result[:cliente]).to include("El cliente no existe")
      expect(result[:almacen]).to be_empty
      expect(result[:cuotas]).to be_empty
      expect(result[:general]).to be_empty
    end

    it 'buckets an error containing "almacén" into :almacen' do
      result = described_class.classify([ "El almacén es requerido" ], sale)
      expect(result[:almacen]).to include("El almacén es requerido")
      expect(result[:cliente]).to be_empty
      expect(result[:cuotas]).to be_empty
      expect(result[:general]).to be_empty
    end

    it 'buckets an error containing "cuota" into :cuotas' do
      result = described_class.classify([ "La cuota 1 tiene un monto inválido" ], sale)
      expect(result[:cuotas]).to include("La cuota 1 tiene un monto inválido")
    end

    it 'buckets an error containing "monto" into :cuotas' do
      result = described_class.classify([ "El monto es inválido" ], sale)
      expect(result[:cuotas]).to include("El monto es inválido")
    end

    it 'buckets an error containing "suma" into :cuotas' do
      result = described_class.classify([ "La suma de cuotas no coincide con el total" ], sale)
      expect(result[:cuotas]).to include("La suma de cuotas no coincide con el total")
    end

    it 'buckets an error with no keyword match into :general' do
      result = described_class.classify([ "Error desconocido" ], sale)
      expect(result[:general]).to include("Error desconocido")
      expect(result[:cliente]).to be_empty
      expect(result[:almacen]).to be_empty
      expect(result[:cuotas]).to be_empty
    end

    it 'distributes multiple errors across different buckets' do
      errors = [
        "El cliente es requerido",
        "La suma de cuotas no coincide con el total",
        "El almacén debe seleccionarse",
        "Error general sin categoría"
      ]
      result = described_class.classify(errors, sale)

      expect(result[:cliente]).to include("El cliente es requerido")
      expect(result[:cuotas]).to include("La suma de cuotas no coincide con el total")
      expect(result[:almacen]).to include("El almacén debe seleccionarse")
      expect(result[:general]).to include("Error general sin categoría")
    end

    it 'folds Sale model validation errors into the right buckets' do
      model_errors = double(full_messages: [ "Cliente debe existir", "Almacén debe existir" ])
      sale_model   = instance_double('Sale', errors: model_errors)

      result = described_class.classify([], sale_model)
      expect(result[:cliente]).to include("Cliente debe existir")
      expect(result[:almacen]).to include("Almacén debe existir")
      expect(result[:cuotas]).to be_empty
      expect(result[:general]).to be_empty
    end

    it 'returns a hash with string keys compatible with view access (Rails style)' do
      result = described_class.classify([ "cliente falta" ], sale)
      # Symbol keys for internal use, but also accessible as strings
      expect(result).to have_key(:cliente)
      expect(result).to have_key(:almacen)
      expect(result).to have_key(:cuotas)
      expect(result).to have_key(:general)
    end
  end
end
