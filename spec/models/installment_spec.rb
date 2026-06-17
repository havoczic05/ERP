require 'rails_helper'

RSpec.describe Installment, type: :model do
  describe 'enums' do
    it 'accepts pendiente as status' do
      installment = build(:installment, status: 'pendiente')
      expect(installment.status).to eq('pendiente')
    end

    it 'accepts pagada as status' do
      installment = build(:installment, status: 'pagada')
      expect(installment.status).to eq('pagada')
    end

    it 'accepts vencida as status' do
      installment = build(:installment, status: 'vencida')
      expect(installment.status).to eq('vencida')
    end

    it 'accepts anulada as status' do
      installment = build(:installment, status: 'anulada')
      expect(installment.status).to eq('anulada')
    end

    it 'raises on an unrecognized status' do
      expect { Installment.new(status: 'unknown') }.to raise_error(ArgumentError)
    end
  end

  describe 'validations' do
    it 'is invalid with amount_usd <= 0' do
      installment = build(:installment, amount_usd: 0)
      expect(installment).not_to be_valid
      expect(installment.errors[:amount_usd]).to be_present
    end

    it 'is valid with amount_usd > 0' do
      installment = build(:installment, amount_usd: 50.00)
      expect(installment).to be_valid
    end

    it 'is invalid without due_date' do
      installment = build(:installment, due_date: nil)
      expect(installment).not_to be_valid
      expect(installment.errors[:due_date]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to sale' do
      association = described_class.reflect_on_association(:sale)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many amortizations' do
      association = described_class.reflect_on_association(:amortizations)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe '.outstanding scope' do
    it 'returns only pendiente installments ordered by due_date asc' do
      old_due  = create(:installment, status: 'pendiente', due_date: 10.days.from_now)
      new_due  = create(:installment, status: 'pendiente', due_date: 20.days.from_now)
      _pagada  = create(:installment, status: 'pagada',    due_date: 5.days.from_now)
      _vencida = create(:installment, status: 'vencida',   due_date: 1.day.ago)

      result = described_class.outstanding
      expect(result).to eq([ old_due, new_due ])
    end

    it 'excludes pagada installments' do
      create(:installment, status: 'pagada', due_date: 1.day.from_now)
      expect(described_class.outstanding).to be_empty
    end
  end

  describe '#overdue?' do
    it 'returns true when pendiente and due_date is in the past' do
      installment = build(:installment, status: 'pendiente', due_date: 1.day.ago)
      expect(installment.overdue?).to be(true)
    end

    it 'returns false when pendiente and due_date is today' do
      installment = build(:installment, status: 'pendiente', due_date: Date.current)
      expect(installment.overdue?).to be(false)
    end

    it 'returns false when pendiente and due_date is in the future' do
      installment = build(:installment, status: 'pendiente', due_date: 1.day.from_now)
      expect(installment.overdue?).to be(false)
    end

    it 'returns false when pagada even if due_date is in the past' do
      installment = build(:installment, status: 'pagada', due_date: 1.day.ago)
      expect(installment.overdue?).to be(false)
    end
  end
end
