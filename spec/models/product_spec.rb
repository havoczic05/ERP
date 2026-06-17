require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'validations' do
    it 'is invalid without name' do
      product = build(:product, name: '')
      expect(product).not_to be_valid
      expect(product.errors[:name]).to be_present
    end

    it 'is invalid without sku' do
      product = build(:product, sku: '')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to be_present
    end

    it 'is invalid without brand' do
      product = build(:product, brand: '')
      expect(product).not_to be_valid
      expect(product.errors[:brand]).to be_present
    end

    it 'is invalid with stock < 0' do
      product = build(:product, stock: -1)
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to be_present
    end

    it 'is valid with stock = 0' do
      product = build(:product, stock: 0)
      expect(product).to be_valid
    end

    it 'is invalid with base_price_usd <= 0' do
      product = build(:product, base_price_usd: 0)
      expect(product).not_to be_valid
      expect(product.errors[:base_price_usd]).to be_present
    end

    it 'is valid with base_price_usd > 0' do
      product = build(:product, base_price_usd: 10.00)
      expect(product).to be_valid
    end
  end

  describe 'sku uniqueness (active products only)' do
    it 'is invalid when sku is taken by another active product' do
      create(:product, sku: 'SKU-001')
      duplicate = build(:product, sku: 'SKU-001')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to be_present
    end

    it 'allows the same sku when the existing product is discarded' do
      create(:product, sku: 'SKU-001', discarded_at: Time.current)
      new_product = build(:product, sku: 'SKU-001')
      expect(new_product).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active) { create(:product) }
    let!(:discarded) { create(:product, discarded_at: Time.current) }

    it 'kept returns only active products' do
      expect(Product.kept).to include(active)
      expect(Product.kept).not_to include(discarded)
    end

    it 'discarded returns only discarded products' do
      expect(Product.discarded).to include(discarded)
      expect(Product.discarded).not_to include(active)
    end
  end

  describe 'soft-delete' do
    it '#discard sets discarded_at' do
      product = create(:product)
      product.discard
      expect(product.discarded_at).not_to be_nil
    end

    it '#undiscard clears discarded_at' do
      product = create(:product, discarded_at: Time.current)
      product.undiscard
      expect(product.reload.discarded_at).to be_nil
    end

    it '#discarded? returns true when discarded_at is set' do
      product = build(:product, discarded_at: Time.current)
      expect(product.discarded?).to be(true)
    end

    it '#discarded? returns false when discarded_at is nil' do
      product = build(:product)
      expect(product.discarded?).to be(false)
    end
  end

  describe 'associations' do
    it 'belongs to warehouse' do
      warehouse = create(:warehouse)
      product = create(:product, warehouse: warehouse)
      expect(product.warehouse).to eq(warehouse)
    end

    it 'has many sale_items' do
      association = described_class.reflect_on_association(:sale_items)
      expect(association.macro).to eq(:has_many)
    end
  end

  # ---------------------------------------------------------------------------
  # destroyable? — RF-PM-4 guard
  # ---------------------------------------------------------------------------
  describe '#destroyable?' do
    context 'when product has no sale_items' do
      it 'returns true' do
        product = create(:product)
        expect(product.destroyable?).to be true
      end
    end

    context 'when product has one sale_item' do
      it 'returns false' do
        product = create(:product)
        create(:sale_item, product: product)
        expect(product.destroyable?).to be false
      end
    end

    context 'when product has multiple sale_items' do
      it 'returns false (guard applies regardless of count)' do
        product = create(:product)
        create_list(:sale_item, 3, product: product)
        expect(product.destroyable?).to be false
      end
    end
  end
end
