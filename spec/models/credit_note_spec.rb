require 'rails_helper'

RSpec.describe CreditNote, type: :model do
  describe 'validations' do
    it 'is invalid with total_usd <= 0' do
      note = build(:credit_note, total_usd: 0)
      expect(note).not_to be_valid
      expect(note.errors[:total_usd]).to be_present
    end

    it 'is valid with total_usd > 0' do
      note = build(:credit_note, total_usd: 100.00)
      expect(note).to be_valid
    end

    it 'is invalid without issued_at' do
      note = build(:credit_note, issued_at: nil)
      expect(note).not_to be_valid
      expect(note.errors[:issued_at]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to sale' do
      association = described_class.reflect_on_association(:sale)
      expect(association.macro).to eq(:belongs_to)
    end
  end
end
