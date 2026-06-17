require 'rails_helper'

# TDD spec for Warehouse#destroyable? (RF-WM-2)
# Tests the dual-FK guard: blocks delete if products OR sales exist.
RSpec.describe Warehouse, type: :model do
  describe '#destroyable?' do
    context 'when warehouse has no products and no sales' do
      it 'returns true' do
        warehouse = create(:warehouse)
        expect(warehouse.destroyable?).to be true
      end
    end

    context 'when warehouse has products' do
      it 'returns false' do
        warehouse = create(:warehouse)
        create(:product, warehouse: warehouse)
        expect(warehouse.destroyable?).to be false
      end
    end

    context 'when warehouse has sales but no products' do
      it 'returns false' do
        warehouse = create(:warehouse)
        create(:sale, warehouse: warehouse)
        expect(warehouse.destroyable?).to be false
      end
    end

    context 'when warehouse has both products and sales' do
      it 'returns false' do
        warehouse = create(:warehouse)
        create(:product, warehouse: warehouse)
        create(:sale, warehouse: warehouse)
        expect(warehouse.destroyable?).to be false
      end
    end
  end

  describe 'associations' do
    it 'has many sales' do
      warehouse = create(:warehouse)
      sale = create(:sale, warehouse: warehouse)
      expect(warehouse.sales).to include(sale)
    end
  end
end
