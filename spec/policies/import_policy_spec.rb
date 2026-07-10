require "rails_helper"

# Policy spec for ImportPolicy — admin-only gate (mirrors CompanySettingsPolicy).
RSpec.describe ImportPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }

  subject { described_class }

  describe "Administrador is permitted" do
    it "grants administrador new?" do
      expect(subject.new(administrador, :import).new?).to be true
    end

    it "grants administrador create?" do
      expect(subject.new(administrador, :import).create?).to be true
    end
  end

  describe "Vendedor is denied" do
    it "denies vendedor new?" do
      expect(subject.new(vendedor, :import).new?).to be false
    end

    it "denies vendedor create?" do
      expect(subject.new(vendedor, :import).create?).to be false
    end
  end

  describe "Nil user is denied" do
    it "denies nil user new?" do
      expect(subject.new(nil, :import).new?).to be false
    end

    it "denies nil user create?" do
      expect(subject.new(nil, :import).create?).to be false
    end
  end
end
