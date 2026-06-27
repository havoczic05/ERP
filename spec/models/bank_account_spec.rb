require 'rails_helper'

RSpec.describe BankAccount, type: :model do
  describe 'validations' do
    it 'is invalid without a bank' do
      record = build(:bank_account, bank: '')
      expect(record).not_to be_valid
      expect(record.errors[:bank]).to be_present
    end

    it 'is valid with a bank and company_settings' do
      expect(build(:bank_account)).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to company_settings' do
      expect(described_class.reflect_on_association(:company_settings).macro).to eq(:belongs_to)
    end
  end

  describe 'Spanish attribute names' do
    it 'humanizes account_number in Spanish' do
      expect(described_class.human_attribute_name(:account_number)).to eq('Cuenta corriente')
    end

    it 'humanizes interbank_number in Spanish' do
      expect(described_class.human_attribute_name(:interbank_number)).to eq('Cuenta interbancaria')
    end
  end
end
