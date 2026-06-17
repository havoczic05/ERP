require 'rails_helper'

# TDD spec for ProductPolicy (RF-PM-6)
# Both administrador and vendedor authorized for ALL actions incl. destroy? and search?.
# destroy? and search? MUST be explicitly declared in ProductPolicy.
RSpec.describe ProductPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:product)       { build(:product) }
  let(:nil_user)      { nil }
  let(:unknown_role)  { build(:user, role: 'cashier') }

  subject { described_class }

  # -----------------------------------------------------------------------
  # Shared examples: both roles allowed on all 8 actions
  # -----------------------------------------------------------------------
  shared_examples 'allows all product actions' do |role_name|
    let(:user) { send(role_name) }

    %i[index? show? new? create? edit? update? destroy? search?].each do |action|
      it "grants #{role_name} #{action}" do
        expect(subject.new(user, product).public_send(action)).to be true
      end
    end
  end

  include_examples 'allows all product actions', :administrador
  include_examples 'allows all product actions', :vendedor

  # -----------------------------------------------------------------------
  # destroy? must be EXPLICITLY declared (not delegated to ApplicationPolicy default)
  # -----------------------------------------------------------------------
  describe 'destroy? is explicitly declared' do
    it 'ProductPolicy instance method list includes destroy?' do
      policy_instance_methods = described_class.instance_methods(false)
      expect(policy_instance_methods).to include(:destroy?)
    end

    it 'ProductPolicy instance method list includes search?' do
      policy_instance_methods = described_class.instance_methods(false)
      expect(policy_instance_methods).to include(:search?)
    end
  end

  # -----------------------------------------------------------------------
  # Unrecognized role is denied
  # -----------------------------------------------------------------------
  describe 'unrecognized / nil role' do
    it 'denies user with nil role' do
      user = build(:user, role: nil)
      expect(subject.new(user, product).index?).to be false
    end

    it 'denies user with unknown role' do
      expect(subject.new(unknown_role, product).index?).to be false
    end

    it 'denies nil user' do
      expect(subject.new(nil_user, product).index?).to be false
    end
  end
end
