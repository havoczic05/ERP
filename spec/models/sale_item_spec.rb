require 'rails_helper'

RSpec.describe SaleItem, type: :model do
  describe 'validations' do
    it 'is invalid with quantity <= 0' do
      item = build(:sale_item, quantity: 0)
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to be_present
    end

    it 'is invalid with negative quantity' do
      item = build(:sale_item, quantity: -1)
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to be_present
    end

    it 'is valid with quantity > 0' do
      item = build(:sale_item, quantity: 1)
      expect(item).to be_valid
    end

    it 'is invalid with unit_price_usd <= 0' do
      item = build(:sale_item, unit_price_usd: 0)
      expect(item).not_to be_valid
      expect(item.errors[:unit_price_usd]).to be_present
    end

    it 'is valid with unit_price_usd > 0' do
      item = build(:sale_item, unit_price_usd: 5.00)
      expect(item).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to sale' do
      association = described_class.reflect_on_association(:sale)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to product' do
      association = described_class.reflect_on_association(:product)
      expect(association.macro).to eq(:belongs_to)
    end
  end
end
