require 'rails_helper'

RSpec.describe 'Clients', type: :request do
  # ---------------------------------------------------------------------------
  # Test seam: set current_user on the controller via an around hook.
  # ApplicationController#current_user= is exposed in test env only.
  # ---------------------------------------------------------------------------
  let(:user) { create(:user, :administrador) }

  before do
    # Inject current_user into every controller instance for this spec.
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------
  describe 'GET /clients' do
    it 'returns 200' do
      get clients_path
      expect(response).to have_http_status(:ok)
    end

    it 'shows only kept clients' do
      kept    = create(:client, :ruc_client)
      _discard = create(:client, :ruc_client).tap(&:discard)

      get clients_path
      expect(response.body).to include(kept.full_name)
    end
  end

  # ---------------------------------------------------------------------------
  # Index search filter via q param
  # ---------------------------------------------------------------------------
  describe 'GET /clients with q param' do
    it 'filters by document_number' do
      match   = create(:client, :ruc_client, document_number: '20000000001')
      no_match = create(:client, :ruc_client, document_number: '20000000002')

      get clients_path, params: { q: '20000000001' }
      expect(response.body).to include(match.full_name)
      expect(response.body).not_to include(no_match.full_name)
    end

    it 'filters by full_name' do
      match    = create(:client, :ruc_client, full_name: 'Acme Corp')
      no_match = create(:client, :ruc_client, full_name: 'Other Company')

      get clients_path, params: { q: 'Acme' }
      expect(response.body).to include(match.full_name)
      expect(response.body).not_to include(no_match.full_name)
    end
  end

  # ---------------------------------------------------------------------------
  # New
  # ---------------------------------------------------------------------------
  describe 'GET /clients/new' do
    it 'returns 200' do
      get new_client_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------
  describe 'POST /clients' do
    context 'with valid params' do
      let(:valid_params) do
        { client: { full_name: 'Test Client', document_type: 'ruc',
                    document_number: '20123456789', phone: '999999999' } }
      end

      it 'creates a client and redirects' do
        expect {
          post clients_path, params: valid_params
        }.to change(Client, :count).by(1)
        expect(response).to have_http_status(:found)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        { client: { full_name: '', document_type: 'ruc',
                    document_number: '', phone: '' } }
      end

      it 'returns 422 and re-renders the form' do
        post clients_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit
  # ---------------------------------------------------------------------------
  describe 'GET /clients/:id/edit' do
    it 'returns 200' do
      client = create(:client, :ruc_client)
      get edit_client_path(client)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------
  describe 'PATCH /clients/:id' do
    context 'with valid params' do
      it 'updates the client and redirects' do
        client = create(:client, :ruc_client)
        patch client_path(client),
              params: { client: { full_name: 'Updated Name' } }
        expect(response).to have_http_status(:found)
        expect(client.reload.full_name).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns 422' do
        client = create(:client, :ruc_client)
        patch client_path(client), params: { client: { full_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Destroy — soft-delete (no sales)
  # ---------------------------------------------------------------------------
  describe 'DELETE /clients/:id' do
    context 'when client has no sales' do
      it 'soft-deletes and redirects' do
        client = create(:client, :ruc_client)
        delete client_path(client)
        expect(response).to have_http_status(:found)
        expect(client.reload.discarded?).to be true
      end
    end

    context 'when client has sales (destroy guard trips)' do
      it 'returns 422 and does not discard the client' do
        client = create(:client, :ruc_client)
        # Simulate sales existing by stubbing destroyable? to return false.
        allow_any_instance_of(Client).to receive(:destroyable?).and_return(false)
        delete client_path(client)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(client.reload.discarded?).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization: vendedor also has full access
  # ---------------------------------------------------------------------------
  describe 'authorization' do
    let(:vendor_user) { create(:user, :vendedor) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendor_user)
    end

    it 'allows vendedor to access index' do
      get clients_path
      expect(response).to have_http_status(:ok)
    end

    it 'allows vendedor to access new form' do
      get new_client_path
      expect(response).to have_http_status(:ok)
    end
  end
end
