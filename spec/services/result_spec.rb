require 'rails_helper'

RSpec.describe Result do
  describe '.success' do
    subject(:result) { described_class.success(obj) }

    let(:obj) { double('payload') }

    it 'exposes payload via :record' do
      expect(result.record).to eq(obj)
    end

    it 'exposes payload via :sale alias (backward-compat)' do
      expect(result.sale).to eq(obj)
    end

    it 'returns the same object from both accessors' do
      expect(result.record).to equal(result.sale)
    end

    it 'is success?' do
      expect(result.success?).to be true
    end

    it 'is not failure?' do
      expect(result.failure?).to be false
    end

    it 'has empty errors' do
      expect(result.errors).to eq([])
    end
  end

  describe '.failure' do
    subject(:result) { described_class.failure(obj, [ 'something went wrong' ]) }

    let(:obj) { double('payload') }

    it 'exposes payload via :record' do
      expect(result.record).to eq(obj)
    end

    it 'exposes payload via :sale alias (backward-compat)' do
      expect(result.sale).to eq(obj)
    end

    it 'is failure?' do
      expect(result.failure?).to be true
    end

    it 'is not success?' do
      expect(result.success?).to be false
    end

    it 'exposes errors' do
      expect(result.errors).to eq([ 'something went wrong' ])
    end
  end

  describe '.failure with nil payload' do
    subject(:result) { described_class.failure }

    it 'record is nil' do
      expect(result.record).to be_nil
    end

    it 'sale alias is nil' do
      expect(result.sale).to be_nil
    end

    it 'errors defaults to empty array' do
      expect(result.errors).to eq([])
    end
  end

  describe '.new keyword backward-compat' do
    it 'accepts sale: keyword and maps it to record' do
      obj = double('legacy')
      result = described_class.new(success: true, sale: obj)
      expect(result.record).to eq(obj)
    end

    it 'accepts record: keyword' do
      obj = double('new-style')
      result = described_class.new(success: true, record: obj)
      expect(result.record).to eq(obj)
    end

    it 'prefers record: over sale: when both are given' do
      rec = double('record')
      sal = double('sale')
      result = described_class.new(success: true, record: rec, sale: sal)
      expect(result.record).to eq(rec)
    end
  end
end
