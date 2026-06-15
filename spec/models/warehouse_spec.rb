require 'rails_helper'

RSpec.describe Warehouse, type: :model do
  describe 'validations' do
    it 'is invalid without name' do
      warehouse = build(:warehouse, name: '')
      expect(warehouse).not_to be_valid
      expect(warehouse.errors[:name]).to be_present
    end

    it 'is valid with a name' do
      warehouse = build(:warehouse, name: 'Main Warehouse')
      expect(warehouse).to be_valid
    end
  end

  describe 'associations' do
    it 'has many products' do
      warehouse = create(:warehouse)
      product = create(:product, warehouse: warehouse)
      expect(warehouse.products).to include(product)
    end
  end
end
