require 'rails_helper'

RSpec.describe Client, type: :model do
  # ---------------------------------------------------------------------------
  # Phase 3: Client Model + Migration
  # ---------------------------------------------------------------------------

  describe 'presence validations' do
    it 'is invalid without full_name' do
      client = build(:client, :ruc_client, full_name: '')
      expect(client).not_to be_valid
      expect(client.errors[:full_name]).to be_present
    end

    it 'is invalid without document_type' do
      client = Client.new(full_name: 'Acme Corp', document_number: '20123456789', phone: '999999999')
      expect(client).not_to be_valid
    end

    it 'is invalid without document_number' do
      client = build(:client, :ruc_client, document_number: '')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end

    it 'is invalid without phone' do
      client = build(:client, :ruc_client, phone: '')
      expect(client).not_to be_valid
      expect(client.errors[:phone]).to be_present
    end
  end

  describe 'document_type enum' do
    it 'accepts ruc as a valid document_type' do
      client = build(:client, :ruc_client)
      expect(client.document_type).to eq('ruc')
    end

    it 'accepts dni as a valid document_type' do
      client = build(:client, :dni_client)
      expect(client.document_type).to eq('dni')
    end

    it 'raises on an unrecognized document_type value' do
      expect {
        Client.new(document_type: 'passport')
      }.to raise_error(ArgumentError)
    end
  end

  describe 'RUC format validation' do
    it 'is valid with exactly 11 digits' do
      client = build(:client, :ruc_client, document_number: '20123456789')
      expect(client).to be_valid
    end

    it 'is invalid with fewer than 11 digits' do
      client = build(:client, :ruc_client, document_number: '2012345678')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end

    it 'is invalid with more than 11 digits' do
      client = build(:client, :ruc_client, document_number: '201234567890')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end

    it 'is invalid with non-numeric characters' do
      client = build(:client, :ruc_client, document_number: '2012345678A')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end
  end

  describe 'DNI format validation' do
    it 'is valid with exactly 8 digits' do
      client = build(:client, :dni_client, document_number: '12345678')
      expect(client).to be_valid
    end

    it 'is invalid with fewer than 8 digits' do
      client = build(:client, :dni_client, document_number: '1234567')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end

    it 'is invalid with more than 8 digits' do
      client = build(:client, :dni_client, document_number: '123456789')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end

    it 'is invalid with non-numeric characters' do
      client = build(:client, :dni_client, document_number: '1234567A')
      expect(client).not_to be_valid
      expect(client.errors[:document_number]).to be_present
    end
  end

  describe 'document_number uniqueness' do
    it 'is invalid when document_number is already taken by an active client' do
      create(:client, :ruc_client, document_number: '20123456789')
      duplicate = build(:client, :ruc_client, document_number: '20123456789')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:document_number]).to be_present
    end

    it 'allows the same document_number when the existing client is discarded' do
      discarded = create(:client, :ruc_client, document_number: '20123456789', discarded_at: Time.current)
      active = build(:client, :ruc_client, document_number: '20123456789')
      # Model-level uniqueness is scoped to kept records; DB partial index enforces the same.
      # NOTE: race-condition safety is provided by the DB partial unique index (WHERE discarded_at IS NULL).
      # Two concurrent requests that both pass model-level validation simultaneously would still be
      # rejected at DB level with ActiveRecord::RecordNotUnique — the controller handles that exception.
      expect(active).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4: Soft-Delete + Destroy Guard
  # ---------------------------------------------------------------------------

  describe '#discard' do
    it 'sets discarded_at to the current time' do
      client = create(:client, :ruc_client)
      now = Time.current
      travel_to(now) do
        client.discard
        expect(client.discarded_at).to be_within(1.second).of(now)
      end
    end

    it 'does not destroy the database row' do
      client = create(:client, :ruc_client)
      client.discard
      expect(Client.unscoped.find_by(id: client.id)).not_to be_nil
    end
  end

  describe '#undiscard' do
    it 'clears discarded_at' do
      client = create(:client, :ruc_client, discarded_at: Time.current)
      client.undiscard
      expect(client.reload.discarded_at).to be_nil
    end
  end

  describe 'Client.kept scope' do
    it 'returns only active (non-discarded) clients' do
      active = create(:client, :ruc_client)
      _discarded = create(:client, :ruc_client,
                          document_number: '20111111111',
                          discarded_at: Time.current)
      expect(Client.kept).to include(active)
      expect(Client.kept).not_to include(_discarded)
    end
  end

  describe 'Client.discarded scope' do
    it 'returns only discarded clients' do
      _active = create(:client, :ruc_client)
      discarded = create(:client, :ruc_client,
                         document_number: '20111111111',
                         discarded_at: Time.current)
      expect(Client.discarded).to include(discarded)
      expect(Client.discarded).not_to include(_active)
    end
  end

  describe '#destroyable?' do
    context 'when the sales table does not exist yet' do
      it 'does not raise and returns true (no sales exist)' do
        client = build(:client, :ruc_client)
        expect { client.destroyable? }.not_to raise_error
        expect(client.destroyable?).to be(true)
      end
    end

    context 'when the client has no sales' do
      it 'returns true' do
        client = create(:client, :ruc_client)
        expect(client.destroyable?).to be(true)
      end
    end

    context 'when the client has a real sale (S-1 debt closure)' do
      it 'returns false' do
        client = create(:client, :ruc_client)
        create(:sale, client: client)
        expect(client.destroyable?).to be(false)
      end

      it 'prevents hard-delete via dependent: :restrict_with_error' do
        client = create(:client, :ruc_client)
        create(:sale, client: client)
        result = client.destroy
        expect(result).to be(false)
        expect(client.errors[:base]).to be_present
        expect(Client.exists?(client.id)).to be(true)
      end
    end
  end
end
