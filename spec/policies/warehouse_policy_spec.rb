require 'rails_helper'

# TDD spec for WarehousePolicy (RF-WM-3)
# administrador: all 7 actions allowed
# vendedor: only index? and show? allowed; denied new?/create?/edit?/update?/destroy?
RSpec.describe WarehousePolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:warehouse)     { build(:warehouse) }

  subject { described_class }

  # -----------------------------------------------------------------------
  # Administrador: all actions allowed
  # -----------------------------------------------------------------------
  shared_examples 'allows all warehouse actions' do |role_name|
    let(:user) { send(role_name) }

    it "grants #{role_name} index?" do
      expect(subject.new(user, warehouse).index?).to be true
    end

    it "grants #{role_name} show?" do
      expect(subject.new(user, warehouse).show?).to be true
    end

    it "grants #{role_name} new?" do
      expect(subject.new(user, warehouse).new?).to be true
    end

    it "grants #{role_name} create?" do
      expect(subject.new(user, warehouse).create?).to be true
    end

    it "grants #{role_name} edit?" do
      expect(subject.new(user, warehouse).edit?).to be true
    end

    it "grants #{role_name} update?" do
      expect(subject.new(user, warehouse).update?).to be true
    end

    it "grants #{role_name} destroy?" do
      expect(subject.new(user, warehouse).destroy?).to be true
    end
  end

  include_examples 'allows all warehouse actions', :administrador

  # -----------------------------------------------------------------------
  # Vendedor: read-only (index + show only)
  # -----------------------------------------------------------------------
  describe 'vendedor' do
    let(:user) { vendedor }

    it 'grants vendedor index?' do
      expect(subject.new(user, warehouse).index?).to be true
    end

    it 'grants vendedor show?' do
      expect(subject.new(user, warehouse).show?).to be true
    end

    it 'denies vendedor new?' do
      expect(subject.new(user, warehouse).new?).to be false
    end

    it 'denies vendedor create?' do
      expect(subject.new(user, warehouse).create?).to be false
    end

    it 'denies vendedor edit?' do
      expect(subject.new(user, warehouse).edit?).to be false
    end

    it 'denies vendedor update?' do
      expect(subject.new(user, warehouse).update?).to be false
    end

    it 'denies vendedor destroy?' do
      expect(subject.new(user, warehouse).destroy?).to be false
    end
  end
end
