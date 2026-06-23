require 'rails_helper'

RSpec.describe ClientPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:client)        { build(:client, :ruc_client) }

  subject { described_class }

  # Administrador: full access.
  describe 'administrador' do
    let(:user) { administrador }

    %i[index? show? new? create? edit? update? destroy? search?].each do |action|
      it "grants #{action}" do
        expect(subject.new(user, client).public_send(action)).to be true
      end
    end
  end

  # Vendedor: read + create only. Cannot edit or archive clients.
  describe 'vendedor' do
    let(:user) { vendedor }

    %i[index? show? new? create? search?].each do |action|
      it "grants #{action}" do
        expect(subject.new(user, client).public_send(action)).to be true
      end
    end

    %i[edit? update? destroy?].each do |action|
      it "denies #{action}" do
        expect(subject.new(user, client).public_send(action)).to be false
      end
    end
  end
end
