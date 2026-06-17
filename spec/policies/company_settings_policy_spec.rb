require 'rails_helper'

# TDD spec for CompanySettingsPolicy (PRD RF5)
# administrador: show?, edit?, update? — all allowed
# vendedor: all three denied
# nil user: all three denied
RSpec.describe CompanySettingsPolicy, type: :policy do
  let(:administrador)     { build(:user, :administrador) }
  let(:vendedor)          { build(:user, :vendedor) }
  let(:company_settings)  { build(:company_settings) }

  subject { described_class }

  # -------------------------------------------------------------------------
  # Administrador is permitted
  # -------------------------------------------------------------------------
  describe 'Administrador is permitted' do
    let(:user) { administrador }

    it 'grants administrador show?' do
      expect(subject.new(user, company_settings).show?).to be true
    end

    it 'grants administrador edit?' do
      expect(subject.new(user, company_settings).edit?).to be true
    end

    it 'grants administrador update?' do
      expect(subject.new(user, company_settings).update?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # Vendedor is denied
  # -------------------------------------------------------------------------
  describe 'Vendedor is denied' do
    let(:user) { vendedor }

    it 'denies vendedor show?' do
      expect(subject.new(user, company_settings).show?).to be false
    end

    it 'denies vendedor edit?' do
      expect(subject.new(user, company_settings).edit?).to be false
    end

    it 'denies vendedor update?' do
      expect(subject.new(user, company_settings).update?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # Nil user is denied
  # -------------------------------------------------------------------------
  describe 'Nil user is denied' do
    let(:user) { nil }

    it 'denies nil user show?' do
      expect(subject.new(user, company_settings).show?).to be false
    end

    it 'denies nil user edit?' do
      expect(subject.new(user, company_settings).edit?).to be false
    end

    it 'denies nil user update?' do
      expect(subject.new(user, company_settings).update?).to be false
    end
  end
end
