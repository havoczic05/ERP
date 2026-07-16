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

  # ---------------------------------------------------------------------------
  # download? — REQ-BKP-103
  # ---------------------------------------------------------------------------
  describe "download?" do
    # SCEN-103-a
    it "grants administrador download?" do
      expect(subject.new(administrador, :backup).download?).to be true
    end

    # SCEN-103-b
    it "denies vendedor download?" do
      expect(subject.new(vendedor, :backup).download?).to be false
    end

    # SCEN-103-c
    it "denies nil user download?" do
      expect(subject.new(nil, :backup).download?).to be false
    end
  end
end
