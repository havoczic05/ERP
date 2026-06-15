require 'rails_helper'

RSpec.describe Sale, type: :model do
  describe 'enums' do
    it 'accepts cotizacion as document_type' do
      sale = build(:sale, document_type: 'cotizacion')
      expect(sale.document_type).to eq('cotizacion')
    end

    it 'accepts venta as document_type' do
      sale = build(:sale, document_type: 'venta')
      expect(sale.document_type).to eq('venta')
    end

    it 'raises on an unrecognized document_type' do
      expect { Sale.new(document_type: 'invalid') }.to raise_error(ArgumentError)
    end

    it 'accepts confirmada as status' do
      sale = build(:sale, status: 'confirmada')
      expect(sale.status).to eq('confirmada')
    end

    it 'accepts anulada as status' do
      sale = build(:sale, status: 'anulada')
      expect(sale.status).to eq('anulada')
    end

    it 'raises on an unrecognized status' do
      expect { Sale.new(status: 'borrador') }.to raise_error(ArgumentError)
    end

    it 'accepts pending as billing_status' do
      sale = build(:sale, billing_status: 'pending')
      expect(sale.billing_status).to eq('pending')
    end
  end

  describe 'validations' do
    it 'is invalid without document_type' do
      sale = build(:sale)
      sale.document_type = nil
      # Clear the enum state
      sale.write_attribute(:document_type, nil)
      expect(sale).not_to be_valid
    end

    it 'is invalid without status' do
      sale = build(:sale)
      sale.write_attribute(:status, nil)
      expect(sale).not_to be_valid
    end

    it 'is invalid without correlative' do
      sale = build(:sale, correlative: nil)
      expect(sale).not_to be_valid
      expect(sale.errors[:correlative]).to be_present
    end

    it 'enforces correlative uniqueness' do
      create(:sale, correlative: 'COT-00001')
      duplicate = build(:sale, correlative: 'COT-00001')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:correlative]).to be_present
    end
  end

  describe 'scopes' do
    let!(:active) { create(:sale) }
    let!(:discarded_sale) { create(:sale, correlative: 'COT-99999', discarded_at: Time.current) }

    it 'kept returns only non-discarded sales' do
      expect(Sale.kept).to include(active)
      expect(Sale.kept).not_to include(discarded_sale)
    end

    it 'discarded returns only discarded sales' do
      expect(Sale.discarded).to include(discarded_sale)
      expect(Sale.discarded).not_to include(active)
    end
  end

  describe 'soft-delete' do
    it '#discard sets discarded_at' do
      sale = create(:sale)
      sale.discard
      expect(sale.discarded_at).not_to be_nil
    end

    it '#undiscard clears discarded_at' do
      sale = create(:sale, discarded_at: Time.current)
      sale.undiscard
      expect(sale.reload.discarded_at).to be_nil
    end

    it '#discarded? returns true when set' do
      sale = build(:sale, discarded_at: Time.current)
      expect(sale.discarded?).to be(true)
    end
  end

  describe 'associations' do
    it 'belongs to client' do
      association = described_class.reflect_on_association(:client)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to warehouse' do
      association = described_class.reflect_on_association(:warehouse)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many sale_items' do
      sale = create(:sale)
      item = create(:sale_item, sale: sale)
      expect(sale.sale_items).to include(item)
    end

    it 'has many installments' do
      sale = create(:sale)
      installment = create(:installment, sale: sale)
      expect(sale.installments).to include(installment)
    end

    it 'has one credit_note' do
      association = described_class.reflect_on_association(:credit_note)
      expect(association.macro).to eq(:has_one)
    end

    it 'has optional belongs_to source_cotizacion' do
      association = described_class.reflect_on_association(:source_cotizacion)
      expect(association).not_to be_nil
      expect(association.options[:optional]).to be(true)
    end
  end
end
