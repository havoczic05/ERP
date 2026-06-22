require 'rails_helper'

# Request spec for GET /clients/search Turbo Frame endpoint (Phase 7).
# Covers all 5 scenarios from spec Capability: client-search.
# Uses request specs (not system specs) because the endpoint returns HTML
# that can be fully asserted without a JS driver — Turbo Frame tags render
# as plain HTML in rack_test.

RSpec.describe 'GET /clients/search', type: :request do
  let(:user) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # ---------------------------------------------------------------------------
  # Happy path — match by document_number
  # ---------------------------------------------------------------------------
  describe 'when q matches a document_number' do
    it 'returns 200 and includes the matched client in the Turbo Frame' do
      match    = create(:client, :ruc_client, document_number: '20111111111', full_name: 'Match Corp')
      no_match = create(:client, :ruc_client, document_number: '20999999999', full_name: 'Other Corp')

      get search_clients_path, params: { q: '20111111111' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Match Corp')
      expect(response.body).not_to include('Other Corp')
    end
  end

  # ---------------------------------------------------------------------------
  # Happy path — match by full_name
  # ---------------------------------------------------------------------------
  describe 'when q matches a full_name' do
    it 'returns 200 and includes the matched client in the Turbo Frame' do
      match    = create(:client, :ruc_client, full_name: 'Electronica Lopez SAC', document_number: '20111111112')
      no_match = create(:client, :ruc_client, full_name: 'Ferreteria Perez',      document_number: '20111111113')

      get search_clients_path, params: { q: 'Lopez' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Electronica Lopez SAC')
      expect(response.body).not_to include('Ferreteria Perez')
    end
  end

  # ---------------------------------------------------------------------------
  # Results are selectable: each row carries the data the picker needs to set
  # sale[client_id] and wires the Stimulus selectClient action.
  # ---------------------------------------------------------------------------
  describe 'result rows' do
    it 'render a selectable option with the client id, name and select action' do
      match = create(:client, :ruc_client, full_name: 'Selectable SAC', document_number: '20111111119')

      get search_clients_path, params: { q: 'Selectable' }

      expect(response.body).to include("data-client-id=\"#{match.id}\"")
      expect(response.body).to include('data-client-name="Selectable SAC"')
      expect(response.body).to include('sale-form#selectClient')
    end
  end

  # ---------------------------------------------------------------------------
  # No match — returns a valid Turbo Frame (no 404/422/500)
  # ---------------------------------------------------------------------------
  describe 'when q matches nothing' do
    it 'returns 200 with a valid Turbo Frame and no client rows' do
      create(:client, :ruc_client, full_name: 'Existing Corp', document_number: '20111111114')

      get search_clients_path, params: { q: 'ZZZNOMATCH' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame')
      expect(response.body).not_to include('Existing Corp')
    end
  end

  # ---------------------------------------------------------------------------
  # Blank q — must NOT raise error; returns a valid Turbo Frame
  # ---------------------------------------------------------------------------
  describe 'when q is blank' do
    it 'returns 200 with a valid Turbo Frame (no 5xx)' do
      get search_clients_path, params: { q: '' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame')
    end

    it 'returns 200 when q param is absent' do
      get search_clients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame')
    end
  end

  # ---------------------------------------------------------------------------
  # Discarded clients are excluded
  # ---------------------------------------------------------------------------
  describe 'when a matching client is discarded' do
    it 'does not appear in the Turbo Frame response' do
      discarded = create(:client, :ruc_client, document_number: '20888888888', full_name: 'Discarded Corp')
      discarded.discard

      get search_clients_path, params: { q: '20888888888' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Discarded Corp')
    end
  end
end
