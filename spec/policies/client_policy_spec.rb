require 'rails_helper'

RSpec.describe ClientPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:client)        { build(:client, :ruc_client) }

  subject { described_class }

  shared_examples 'allows all CRUD actions' do |role_name|
    let(:user) { send(role_name) }

    it "grants #{role_name} index?" do
      expect(subject.new(user, client).index?).to be true
    end

    it "grants #{role_name} show?" do
      expect(subject.new(user, client).show?).to be true
    end

    it "grants #{role_name} create?" do
      expect(subject.new(user, client).create?).to be true
    end

    it "grants #{role_name} update?" do
      expect(subject.new(user, client).update?).to be true
    end

    it "grants #{role_name} destroy?" do
      expect(subject.new(user, client).destroy?).to be true
    end

    it "grants #{role_name} new?" do
      expect(subject.new(user, client).new?).to be true
    end

    it "grants #{role_name} edit?" do
      expect(subject.new(user, client).edit?).to be true
    end
  end

  include_examples 'allows all CRUD actions', :administrador
  include_examples 'allows all CRUD actions', :vendedor
end
