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

  # ---------------------------------------------------------------------------
  # Default-warehouse destroy guard (RF-DW-5)
  # ---------------------------------------------------------------------------
  describe '#default_for_company?' do
    it 'returns true when it is the configured default warehouse' do
      warehouse = create(:warehouse)
      create(:company_settings, default_warehouse: warehouse)
      expect(warehouse.default_for_company?).to be true
    end

    it 'returns false when it is not the configured default warehouse' do
      warehouse = create(:warehouse)
      other = create(:warehouse)
      create(:company_settings, default_warehouse: other)
      expect(warehouse.default_for_company?).to be false
    end

    it 'returns false when no default warehouse is configured' do
      warehouse = create(:warehouse)
      expect(warehouse.default_for_company?).to be false
    end
  end

  describe '#destroyable? with the default-warehouse guard' do
    it 'returns false when the warehouse is the configured default, even with no products/sales' do
      warehouse = create(:warehouse)
      create(:company_settings, default_warehouse: warehouse)
      expect(warehouse.destroyable?).to be false
    end

    it 'returns true when the warehouse is not the default and has no products/sales' do
      warehouse = create(:warehouse)
      other = create(:warehouse)
      create(:company_settings, default_warehouse: other)
      expect(warehouse.destroyable?).to be true
    end
  end
end
