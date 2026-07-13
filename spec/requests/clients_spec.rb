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
  # Index filter by document_type
  # ---------------------------------------------------------------------------
  describe 'GET /clients with document_type param' do
    it 'filters by document_type' do
      ruc = create(:client, :ruc_client, full_name: 'Empresa RUC')
      dni = create(:client, :dni_client, full_name: 'Persona DNI')

      get clients_path, params: { document_type: 'dni' }
      expect(response.body).to include(dni.full_name)
      expect(response.body).not_to include(ruc.full_name)
    end

    it 'ignores unknown document_type values (no error)' do
      ruc = create(:client, :ruc_client, full_name: 'Empresa RUC')

      get clients_path, params: { document_type: 'bogus' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ruc.full_name)
    end
  end

  # ---------------------------------------------------------------------------
  # CSV export
  # ---------------------------------------------------------------------------
  describe 'GET /clients.csv' do
    it 'exports a CSV with headers, upper-cased document type, and direccion' do
      create(:client, :ruc_client, full_name: 'Acme Corp',
                                   document_number: '20123456789',
                                   phone: '999111222', direccion: 'Av. Central 100')

      get clients_path(format: :csv)
      expect(response.media_type).to eq('text/csv')
      expect(response.body).to include('Nombre completo,Tipo de documento,Número de documento,Teléfono,Dirección')
      expect(response.body).to include('Acme Corp')
      expect(response.body).to include('RUC')
      expect(response.body).to include('20123456789')
      expect(response.body).to include('Av. Central 100')
    end

    it 'respects the document_type filter' do
      create(:client, :ruc_client, full_name: 'Empresa RUC')
      create(:client, :dni_client, full_name: 'Persona DNI')

      get clients_path(format: :csv, document_type: 'dni')
      expect(response.body).to include('Persona DNI')
      expect(response.body).not_to include('Empresa RUC')
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

    context 'as a Turbo Stream request (modal flow)' do
      let(:valid_params) do
        { client: { full_name: 'Toast SA', document_type: 'ruc',
                    document_number: '20999888777', phone: '999000111' } }
      end
      let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

      it 'closes the modal, prepends the row and appends a toast' do
        post clients_path, params: valid_params, headers: turbo_headers

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('action="prepend"', 'target="clients"')
        expect(response.body).to include('action="append"', 'target="toasts"')
        expect(response.body).to include('Cliente creado correctamente.')
        expect(response.body).to include('Toast SA')
      end
    end

    context 'as a Turbo Stream request from the sale form (context: sale)' do
      let(:sale_params) do
        { client: { full_name: 'Venta SA', document_type: 'ruc',
                    document_number: '20111222333', phone: '988000111' },
          context: 'sale' }
      end
      let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

      it 'closes the modal and appends the auto-select bridge (no clients-table row)' do
        post clients_path, params: sale_params, headers: turbo_headers

        expect(Client.find_by(document_number: '20111222333')).to be_present
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('action="append"', 'target="sale-client-receiver"')
        expect(response.body).to include('client-autoselect')          # the bridge controller
        expect(response.body).to include('Venta SA')
        expect(response.body).not_to include('target="clients"')       # no clients-table prepend
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

    context 'as a Turbo Stream request (modal flow)' do
      it 'replaces the row, closes the modal and appends a toast' do
        client = create(:client, :ruc_client)
        patch client_path(client),
              params: { client: { full_name: 'Updated Name' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="replace"', %(target="client_#{client.id}"))
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('Cliente actualizado correctamente.')
        expect(response.body).to include('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns 422' do
        client = create(:client, :ruc_client)
        patch client_path(client), params: { client: { full_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as a Turbo Stream request from the sale form (context: sale)' do
      it 'closes the modal and appends the auto-select bridge (no clients-table row)' do
        client = create(:client, :ruc_client, full_name: 'Old Name', document_number: '20111222333')
        patch client_path(client),
              params: { client: { full_name: 'Updated for Sale' }, context: 'sale' },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(client.reload.full_name).to eq('Updated for Sale')
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('action="append"', 'target="sale-client-receiver"')
        expect(response.body).to include('client-autoselect')
        expect(response.body).to include('Updated for Sale')
        expect(response.body).to include('Cliente actualizado y seleccionado.')
        expect(response.body).not_to include('target="clients"')
        expect(response.body).not_to include(%(target="client_#{client.id}"))
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
      it 'redirects to index with an alert and does not discard the client' do
        client = create(:client, :ruc_client)
        # Simulate sales existing by stubbing destroyable? to return false.
        allow_any_instance_of(Client).to receive(:destroyable?).and_return(false)
        delete client_path(client)
        expect(response).to redirect_to(clients_path)
        expect(client.reload.discarded?).to be false
        expect(flash[:alert]).to include('No se puede eliminar')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization: vendedor can read + create, but NOT edit/update/archive
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

    it 'allows vendedor to create' do
      expect {
        post clients_path, params: { client: { full_name: 'V Client', document_type: 'ruc',
                                               document_number: '20123456789', phone: '999999999' } }
      }.to change(Client, :count).by(1)
    end

    it 'denies vendedor the edit form (403)' do
      client = create(:client, :ruc_client)
      get edit_client_path(client)
      expect(response).to have_http_status(:forbidden)
    end

    it 'denies vendedor update (403)' do
      client = create(:client, :ruc_client)
      patch client_path(client), params: { client: { full_name: 'X' } }
      expect(response).to have_http_status(:forbidden)
    end

    it 'denies vendedor archive/destroy (403)' do
      client = create(:client, :ruc_client)
      delete client_path(client)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
