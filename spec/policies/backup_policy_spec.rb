require "rails_helper"

# Policy spec for BackupPolicy — admin-only gate (mirrors ImportPolicy).
RSpec.describe BackupPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }

  subject { described_class }

  describe "Administrador is permitted" do
    it "grants administrador new?" do
      expect(subject.new(administrador, :backup).new?).to be true
    end

    it "grants administrador create?" do
      expect(subject.new(administrador, :backup).create?).to be true
    end
  end

  describe "Vendedor is denied" do
    it "denies vendedor new?" do
      expect(subject.new(vendedor, :backup).new?).to be false
    end

    it "denies vendedor create?" do
      expect(subject.new(vendedor, :backup).create?).to be false
    end
  end

  describe "Nil user is denied" do
    it "denies nil user new?" do
      expect(subject.new(nil, :backup).new?).to be false
    end

    it "denies nil user create?" do
      expect(subject.new(nil, :backup).create?).to be false
    end
  end
end
