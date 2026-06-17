require 'rails_helper'

# Request specs for WarehousesController (RF-WM-1, RF-WM-2, RF-WM-3).
# Covers: CRUD happy/sad paths, dual-FK destroy guard, role enforcement.
RSpec.describe 'Warehouses', type: :request do
  # ---------------------------------------------------------------------------
  # Auth seam: inject current_user into ApplicationController.
  # ---------------------------------------------------------------------------
  let(:admin)   { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Index — both roles
  # ---------------------------------------------------------------------------
  describe 'GET /warehouses' do
    it 'returns 200 for administrador' do
      get warehouses_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the warehouse list' do
      wh = create(:warehouse, name: 'Main Depot')
      get warehouses_path
      expect(response.body).to include('Main Depot')
    end
  end

  # ---------------------------------------------------------------------------
  # Show — both roles
  # ---------------------------------------------------------------------------
  describe 'GET /warehouses/:id' do
    it 'returns 200' do
      wh = create(:warehouse)
      get warehouse_path(wh)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # New — admin only
  # ---------------------------------------------------------------------------
  describe 'GET /warehouses/new' do
    it 'returns 200 for administrador' do
      get new_warehouse_path
      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get new_warehouse_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Create (RF-WM-1)
  # ---------------------------------------------------------------------------
  describe 'POST /warehouses' do
    context 'with valid params' do
      it 'creates the warehouse and redirects' do
        expect {
          post warehouses_path, params: { warehouse: { name: 'New Depot', location: 'Lima' } }
        }.to change(Warehouse, :count).by(1)
        expect(response).to have_http_status(:found)
      end
    end

    context 'with blank name' do
      it 'returns 422' do
        post warehouses_path, params: { warehouse: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'returns 403 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      post warehouses_path, params: { warehouse: { name: 'X' } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Edit
  # ---------------------------------------------------------------------------
  describe 'GET /warehouses/:id/edit' do
    it 'returns 200 for administrador' do
      wh = create(:warehouse)
      get edit_warehouse_path(wh)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Update (RF-WM-1)
  # ---------------------------------------------------------------------------
  describe 'PATCH /warehouses/:id' do
    context 'with valid params' do
      it 'updates and redirects' do
        wh = create(:warehouse, name: 'Old Name')
        patch warehouse_path(wh), params: { warehouse: { name: 'New Name' } }
        expect(response).to have_http_status(:found)
        expect(wh.reload.name).to eq('New Name')
      end
    end

    context 'with blank name' do
      it 'returns 422' do
        wh = create(:warehouse)
        patch warehouse_path(wh), params: { warehouse: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'returns 403 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      wh = create(:warehouse)
      patch warehouse_path(wh), params: { warehouse: { name: 'X' } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Destroy — dual-FK guard (RF-WM-2)
  # ---------------------------------------------------------------------------
  describe 'DELETE /warehouses/:id' do
    context 'when warehouse has no products and no sales' do
      it 'hard-deletes and redirects 302' do
        wh = create(:warehouse)
        expect {
          delete warehouse_path(wh)
        }.to change(Warehouse, :count).by(-1)
        expect(response).to have_http_status(:found)
      end
    end

    context 'when warehouse has a product' do
      it 'returns 422 and warehouse persists' do
        wh = create(:warehouse)
        create(:product, warehouse: wh)
        expect {
          delete warehouse_path(wh)
        }.not_to change(Warehouse, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when warehouse has a sale (no products)' do
      it 'returns 422 and warehouse persists' do
        wh = create(:warehouse)
        create(:sale, warehouse: wh)
        expect {
          delete warehouse_path(wh)
        }.not_to change(Warehouse, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when warehouse has both products and sales' do
      it 'returns 422 and warehouse persists' do
        wh = create(:warehouse)
        create(:product, warehouse: wh)
        create(:sale, warehouse: wh)
        expect {
          delete warehouse_path(wh)
        }.not_to change(Warehouse, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'returns 403 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      wh = create(:warehouse)
      delete warehouse_path(wh)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Role enforcement: vendedor can access index and show
  # ---------------------------------------------------------------------------
  describe 'authorization — vendedor read access' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
    end

    it 'allows vendedor index' do
      get warehouses_path
      expect(response).to have_http_status(:ok)
    end

    it 'allows vendedor show' do
      wh = create(:warehouse)
      get warehouse_path(wh)
      expect(response).to have_http_status(:ok)
    end
  end
end
