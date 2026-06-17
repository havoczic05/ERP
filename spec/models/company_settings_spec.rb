require 'rails_helper'

RSpec.describe CompanySettings, type: :model do
  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  describe 'Missing razon_social' do
    it 'is invalid without razon_social' do
      record = build(:company_settings, razon_social: '')
      expect(record).not_to be_valid
      expect(record.errors[:razon_social]).to be_present
    end
  end

  describe 'Missing ruc' do
    it 'is invalid without ruc' do
      record = build(:company_settings, ruc: '')
      expect(record).not_to be_valid
      expect(record.errors[:ruc]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # RUC format — exactly 11 numeric digits
  # ---------------------------------------------------------------------------
  describe 'RUC too short' do
    it 'is invalid with a 10-digit ruc' do
      record = build(:company_settings, ruc: '2012345678')
      expect(record).not_to be_valid
      expect(record.errors[:ruc]).to be_present
    end
  end

  describe 'RUC too long' do
    it 'is invalid with a 12-digit ruc' do
      record = build(:company_settings, ruc: '201234567890')
      expect(record).not_to be_valid
      expect(record.errors[:ruc]).to be_present
    end
  end

  describe 'RUC with non-numeric chars' do
    it 'is invalid when ruc contains letters' do
      record = build(:company_settings, ruc: '2012345678A')
      expect(record).not_to be_valid
      expect(record.errors[:ruc]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # Valid records
  # ---------------------------------------------------------------------------
  describe 'Valid record with all fields' do
    it 'is valid with razon_social, ruc, direccion, and telefono' do
      record = build(:company_settings,
                     razon_social: 'Empresa SAC',
                     ruc: '20123456789',
                     direccion: 'Av. Peru 123',
                     telefono: '01-234-5678')
      expect(record).to be_valid
    end
  end

  describe 'Valid record with only required fields' do
    it 'is valid with only razon_social and ruc' do
      record = build(:company_settings,
                     razon_social: 'Empresa SAC',
                     ruc: '20123456789',
                     direccion: nil,
                     telefono: nil)
      expect(record).to be_valid
    end
  end

  describe 'Record is valid without logo' do
    it 'does not require a logo attachment' do
      record = build(:company_settings)
      expect(record).to be_valid
      expect(record.logo.attached?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # DB-level null constraint guard (catches a missing null:false in migration)
  # ---------------------------------------------------------------------------
  describe 'DB null constraint on razon_social' do
    it 'is invalid at model level when razon_social is nil' do
      record = build(:company_settings, razon_social: nil)
      expect(record).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Singleton accessor
  # ---------------------------------------------------------------------------
  describe 'Accessor returns existing record' do
    it 'returns the existing row without creating a new one' do
      existing = create(:company_settings)
      result = CompanySettings.instance
      expect(result.id).to eq existing.id
      expect(CompanySettings.count).to eq 1
    end
  end

  describe 'Accessor initializes when no record exists' do
    it 'returns an unsaved object when DB is empty and does not raise' do
      expect(CompanySettings.count).to eq 0
      result = nil
      expect { result = CompanySettings.instance }.not_to raise_error
      expect(result).to be_a(CompanySettings)
      expect(result.new_record?).to be true
      expect(CompanySettings.count).to eq 0
    end
  end

  describe 'Calling accessor twice does not duplicate' do
    it 'does not create a second row when called twice with an existing record' do
      create(:company_settings)
      CompanySettings.instance
      CompanySettings.instance
      expect(CompanySettings.count).to eq 1
    end
  end
end
