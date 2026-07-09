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

  # ---------------------------------------------------------------------------
  # Subtitulo (optional)
  # ---------------------------------------------------------------------------
  describe 'subtitulo' do
    it 'is valid with a subtitulo' do
      expect(build(:company_settings, subtitulo: 'Importadora y Distribuidora')).to be_valid
    end

    it 'is valid without a subtitulo' do
      expect(build(:company_settings, subtitulo: nil)).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Default warehouse (RF-DW-1)
  # ---------------------------------------------------------------------------
  describe 'default_warehouse association' do
    it 'is optional (valid without a default warehouse)' do
      expect(build(:company_settings, default_warehouse: nil)).to be_valid
    end

    it 'persists the chosen default warehouse id' do
      warehouse = create(:warehouse, name: 'Almacén Central')
      settings = create(:company_settings, default_warehouse: warehouse)
      expect(settings.reload.default_warehouse_id).to eq(warehouse.id)
      expect(settings.default_warehouse).to eq(warehouse)
    end

    it 'allows clearing the default warehouse back to nil' do
      warehouse = create(:warehouse)
      settings = create(:company_settings, default_warehouse: warehouse)
      settings.update(default_warehouse_id: nil)
      expect(settings.reload.default_warehouse_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Default warehouse must reference an existing warehouse (reliability fix —
  # a warehouse deleted between page load and submit, or a crafted request,
  # must fail gracefully instead of raising ActiveRecord::InvalidForeignKey).
  # ---------------------------------------------------------------------------
  describe 'default_warehouse_id must reference an existing warehouse' do
    it 'is invalid when default_warehouse_id does not reference an existing warehouse' do
      record = build(:company_settings, default_warehouse_id: 999_999)
      expect(record).not_to be_valid
      expect(record.errors[:default_warehouse_id]).to be_present
    end

    it 'does not raise and does not persist when saved with a non-existent default_warehouse_id' do
      record = build(:company_settings, default_warehouse_id: 999_999)
      expect { expect(record.save).to be false }.not_to raise_error
      expect(record).not_to be_persisted
    end

    it 'stays valid when default_warehouse_id is blank (clearing the default)' do
      expect(build(:company_settings, default_warehouse_id: nil)).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Bank accounts association
  # ---------------------------------------------------------------------------
  describe 'bank_accounts association' do
    it 'has many bank accounts ordered by position' do
      settings = create(:company_settings)
      second = create(:bank_account, company_settings: settings, bank: 'BCP', position: 2)
      first  = create(:bank_account, company_settings: settings, bank: 'BBVA', position: 1)
      expect(settings.bank_accounts.reload.to_a).to eq([ first, second ])
    end

    it 'destroys its bank accounts when the settings row is destroyed' do
      settings = create(:company_settings)
      create(:bank_account, company_settings: settings)
      expect { settings.destroy }.to change(BankAccount, :count).by(-1)
    end
  end

  # ---------------------------------------------------------------------------
  # Nested attributes for bank accounts
  # ---------------------------------------------------------------------------
  describe 'nested attributes for bank_accounts' do
    it 'creates bank accounts from nested attributes' do
      settings = create(:company_settings)
      settings.update(bank_accounts_attributes: [ { bank: 'BCP', currency_label: 'Soles' } ])
      expect(settings.bank_accounts.count).to eq(1)
    end

    it 'rejects rows with a blank bank' do
      settings = create(:company_settings)
      settings.update(bank_accounts_attributes: [ { bank: '', account_number: '', position: '0' } ])
      expect(settings.bank_accounts.count).to eq(0)
    end

    it 'destroys a bank account via _destroy' do
      settings = create(:company_settings)
      account  = create(:bank_account, company_settings: settings)
      settings.update(bank_accounts_attributes: [ { id: account.id, _destroy: '1' } ])
      expect(settings.bank_accounts.count).to eq(0)
    end
  end
end
