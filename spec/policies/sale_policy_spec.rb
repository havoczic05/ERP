require 'rails_helper'

RSpec.describe SalePolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:sale)          { build(:sale) }

  subject { described_class }

  # ---------------------------------------------------------------------------
  # Actions available to both roles
  # ---------------------------------------------------------------------------
  shared_examples 'grants access to both roles' do |action|
    it "grants administrador #{action}" do
      expect(subject.new(administrador, sale).public_send(action)).to be true
    end

    it "grants vendedor #{action}" do
      expect(subject.new(vendedor, sale).public_send(action)).to be true
    end
  end

  include_examples 'grants access to both roles', :index?
  include_examples 'grants access to both roles', :show?
  include_examples 'grants access to both roles', :new?
  include_examples 'grants access to both roles', :create?
  include_examples 'grants access to both roles', :convert_to_sale?

  # ---------------------------------------------------------------------------
  # annul? — administrador only
  # ---------------------------------------------------------------------------
  describe '#annul?' do
    it 'grants administrador' do
      expect(subject.new(administrador, sale).annul?).to be true
    end

    it 'denies vendedor' do
      expect(subject.new(vendedor, sale).annul?).to be false
    end

    it 'denies nil user' do
      expect(subject.new(nil, sale).annul?).to be false
    end
  end
end
