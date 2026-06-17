require 'rails_helper'

# Spec for Slice 3 — Global authenticate_user! guard (RF-AUTH-3).
#
# Verifies:
#   - Unauthenticated requests to protected routes are redirected to login_path.
#   - Authenticated requests pass through the guard (200).
#   - Wrong-role (authz) still returns 403, NOT a redirect (authn vs authz split).
#   - /login (sessions#new) is reachable without auth (skip_before_action).
#   - /up (rails/health#show) is reachable without auth (engine controller).
RSpec.describe 'Authentication Guard', type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  # ---------------------------------------------------------------------------
  # Unauthenticated access to a protected resource
  # ---------------------------------------------------------------------------
  describe 'GET /clients (unauthenticated)' do
    it 'redirects to login_path' do
      get clients_path
      expect(response).to redirect_to(login_path)
    end

    it 'sets an alert flash message' do
      get clients_path
      expect(flash[:alert]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # Authenticated access passes the guard
  # ---------------------------------------------------------------------------
  describe 'GET /clients (authenticated admin)' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
    end

    it 'returns 200' do
      get clients_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Wrong-role user gets 403 (authz), NOT a redirect (authn)
  # Proves the authn vs authz split: guard passes (current_user present),
  # Pundit raises NotAuthorized -> head :forbidden.
  # ---------------------------------------------------------------------------
  describe 'GET /warehouses/new (authenticated vendedor — admin-only)' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
    end

    it 'returns 403 forbidden, not a redirect' do
      get new_warehouse_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # /login is reachable without authentication (skip_before_action)
  # ---------------------------------------------------------------------------
  describe 'GET /login (unauthenticated)' do
    it 'returns 200' do
      get login_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # /up health check is reachable without authentication (engine controller)
  # Regression: rails/health#show does NOT inherit ApplicationController,
  # so authenticate_user! never runs on this route.
  # ---------------------------------------------------------------------------
  describe 'GET /up (unauthenticated)' do
    it 'returns 200' do
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end
  end
end
