require 'rails_helper'

RSpec.describe AmortizationPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:amortization)  { build(:amortization) }

  subject { described_class }

  # ---------------------------------------------------------------------------
  # Actions available to both roles
  # ---------------------------------------------------------------------------
  shared_examples 'grants access to both roles' do |action|
    it "grants administrador #{action}" do
      expect(subject.new(administrador, amortization).public_send(action)).to be true
    end

    it "grants vendedor #{action}" do
      expect(subject.new(vendedor, amortization).public_send(action)).to be true
    end
  end

  include_examples 'grants access to both roles', :index?
  include_examples 'grants access to both roles', :create?

  # ---------------------------------------------------------------------------
  # Nil user is denied
  # ---------------------------------------------------------------------------
  describe '#create? with nil user' do
    it 'denies nil user' do
      expect(subject.new(nil, amortization).create?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Role outside ALLOWED_ROLES is denied
  # ---------------------------------------------------------------------------
  describe '#create? with unknown role' do
    let(:other_user) { build(:user, role: 'contador') }

    it 'denies a role not in ALLOWED_ROLES' do
      expect(subject.new(other_user, amortization).create?).to be false
    end
  end
end
