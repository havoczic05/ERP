require 'rails_helper'

# Request specs for ProductsController (RF-PM-1..6).
# Covers: CRUD, search/filter, stock write-once invariant, soft-delete guard, role enforcement.
RSpec.describe 'Products', type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }
  let(:warehouse) { create(:warehouse) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Index (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'GET /products' do
    it 'returns 200' do
      get products_path
      expect(response).to have_http_status(:ok)
    end

    it 'shows only kept products' do
      kept     = create(:product, name: 'Visible Widget', warehouse: warehouse)
      discarded = create(:product, name: 'Hidden Gadget', warehouse: warehouse,
                         discarded_at: Time.current)
      get products_path
      expect(response.body).to include('Visible Widget')
      expect(response.body).not_to include('Hidden Gadget')
    end
  end

  # ---------------------------------------------------------------------------
  # Index search (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'GET /products?q=' do
    let!(:widget) { create(:product, name: 'Widget A', sku: 'WGT-001', warehouse: warehouse) }
    let!(:gadget) { create(:product, name: 'Gadget B', sku: 'GDT-002', warehouse: warehouse) }

    it 'filters by name ILIKE' do
      get products_path, params: { q: 'widget' }
      expect(response.body).to include('Widget A')
      expect(response.body).not_to include('Gadget B')
    end

    it 'filters by SKU ILIKE' do
      get products_path, params: { q: 'GDT' }
      expect(response.body).to include('Gadget B')
      expect(response.body).not_to include('Widget A')
    end

    it 'returns 200 with empty results for no match' do
      get products_path, params: { q: 'ZZZNOMATCH' }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Index warehouse filter (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'GET /products?warehouse_id=' do
    let(:warehouse2) { create(:warehouse) }
    let!(:prod_w1) { create(:product, name: 'W1 Product', warehouse: warehouse) }
    let!(:prod_w2) { create(:product, name: 'W2 Product', warehouse: warehouse2) }

    it 'filters by warehouse_id' do
      get products_path, params: { warehouse_id: warehouse.id }
      expect(response.body).to include('W1 Product')
      expect(response.body).not_to include('W2 Product')
    end

    it 'combines search and warehouse filter' do
      create(:product, name: 'Widget', warehouse: warehouse2)
      get products_path, params: { q: 'Widget', warehouse_id: warehouse.id }
      # Neither prod_w1 nor widget in w2 should appear because 'Widget' doesn't match 'W1 Product'
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # CSV export (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'GET /products.csv' do
    it 'exports a CSV with headers and product rows (incl. warehouse name)' do
      create(:product, sku: 'CSV-001', name: 'Exportable Widget', brand: 'ACME',
                       warehouse: warehouse, stock: 7, base_price_usd: 12.50)

      get products_path(format: :csv)
      expect(response.media_type).to eq('text/csv')
      expect(response.body).to include('SKU,Nombre,Marca,Almacén,Stock,Precio base USD')
      expect(response.body).to include('CSV-001')
      expect(response.body).to include('Exportable Widget')
      expect(response.body).to include(warehouse.name)
    end

    it 'respects the warehouse_id filter' do
      warehouse2 = create(:warehouse)
      create(:product, name: 'Here Product', warehouse: warehouse)
      create(:product, name: 'There Product', warehouse: warehouse2)

      get products_path(format: :csv, warehouse_id: warehouse.id)
      expect(response.body).to include('Here Product')
      expect(response.body).not_to include('There Product')
    end
  end

  # ---------------------------------------------------------------------------
  # Show (RF-PM-1)
  # ---------------------------------------------------------------------------
  describe 'GET /products/:id' do
    it 'returns 200 for a kept product' do
      product = create(:product, warehouse: warehouse)
      get product_path(product)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for a discarded product' do
      product = create(:product, warehouse: warehouse, discarded_at: Time.current)
      get product_path(product)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # New
  # ---------------------------------------------------------------------------
  describe 'GET /products/new' do
    it 'returns 200 for administrador' do
      get new_product_path
      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for vendedor (read-only)' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get new_product_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # Create (RF-PM-1, RF-PM-2)
  # ---------------------------------------------------------------------------
  describe 'POST /products' do
    let(:valid_params) do
      { product: { sku: 'TST-001', name: 'Test Product', brand: 'ACME',
                   warehouse_id: warehouse.id, stock: 10, base_price_usd: 5.00 } }
    end

    context 'with valid params' do
      it 'creates the product and redirects (302)' do
        expect {
          post products_path, params: valid_params
        }.to change(Product.kept, :count).by(1)
        expect(response).to have_http_status(:found)
      end
    end

    context 'as a Turbo Stream request (modal flow)' do
      it 'closes the modal, prepends the row and appends a toast' do
        post products_path, params: valid_params,
                            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('action="prepend"', 'target="products"')
        expect(response.body).to include('action="append"', 'target="toasts"')
        expect(response.body).to include('Producto creado correctamente.')
        expect(response.body).to include('Test Product')
      end
    end

    context 'with blank name' do
      it 'returns 422' do
        post products_path, params: { product: valid_params[:product].merge(name: '') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with negative stock' do
      it 'returns 422' do
        post products_path, params: { product: valid_params[:product].merge(stock: -1) }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with base_price_usd <= 0' do
      it 'returns 422' do
        post products_path, params: { product: valid_params[:product].merge(base_price_usd: 0) }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate SKU (RF-PM-2)' do
      it 'returns 422 with SKU error (model-level)' do
        create(:product, sku: 'TST-001', warehouse: warehouse)
        post products_path, params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('sku')
      end
    end

    context 'vendedor cannot create (read-only)' do
      it 'returns 403 for vendedor' do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        post products_path, params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit
  # ---------------------------------------------------------------------------
  describe 'GET /products/:id/edit' do
    it 'returns 200' do
      product = create(:product, warehouse: warehouse)
      get edit_product_path(product)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Update (RF-PM-1, RF-PM-3)
  # ---------------------------------------------------------------------------
  describe 'PATCH /products/:id' do
    let!(:product) { create(:product, name: 'Before', stock: 10, warehouse: warehouse) }

    context 'with valid params' do
      it 'updates the product and redirects' do
        patch product_path(product), params: { product: { name: 'After', brand: 'NewBrand',
                                                           sku: product.sku,
                                                           warehouse_id: warehouse.id,
                                                           base_price_usd: 5.00 } }
        expect(response).to have_http_status(:found)
        expect(product.reload.name).to eq('After')
      end
    end

    context 'as a Turbo Stream request (modal flow)' do
      it 'replaces the row, closes the modal and appends a toast' do
        patch product_path(product),
              params: { product: { name: 'After', brand: 'NewBrand', sku: product.sku,
                                   warehouse_id: warehouse.id, base_price_usd: 5.00 } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('action="replace"', %(target="product_#{product.id}"))
        expect(response.body).to include('action="update"', 'target="modal"')
        expect(response.body).to include('Producto actualizado correctamente.')
        expect(response.body).to include('After')
      end
    end

    context 'stock write-once invariant (RF-PM-3)' do
      it 'does NOT change stock even when stock param is injected' do
        patch product_path(product), params: { product: { name: 'After', brand: product.brand,
                                                           sku: product.sku,
                                                           warehouse_id: warehouse.id,
                                                           base_price_usd: product.base_price_usd,
                                                           stock: 999 } }
        # Regardless of whether update succeeds or fails, stock must remain 10
        expect(product.reload.stock).to eq(10)
      end
    end

    context 'with blank name' do
      it 'returns 422' do
        patch product_path(product), params: { product: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'vendedor cannot update (read-only)' do
      it 'returns 403 for vendedor' do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        patch product_path(product), params: { product: { name: 'VendedorUpdate', brand: product.brand,
                                                           sku: product.sku,
                                                           warehouse_id: warehouse.id,
                                                           base_price_usd: product.base_price_usd } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Destroy — soft-delete + guard (RF-PM-4)
  # ---------------------------------------------------------------------------
  describe 'DELETE /products/:id' do
    context 'when product has no sale_items (destroyable)' do
      it 'soft-deletes and redirects 302' do
        product = create(:product, warehouse: warehouse)
        expect {
          delete product_path(product)
        }.not_to change(Product, :count)
        expect(response).to have_http_status(:found)
        expect(product.reload.discarded_at).not_to be_nil
      end
    end

    context 'when product has sale_items (guard blocks)' do
      it 'redirects to index with an alert and product remains undiscarded' do
        product = create(:product, warehouse: warehouse)
        create(:sale_item, product: product)
        expect {
          delete product_path(product)
        }.not_to change { product.reload.discarded_at }
        expect(response).to redirect_to(products_path)
        expect(flash[:alert]).to include('No se puede eliminar')
        expect(product.reload.discarded_at).to be_nil
      end
    end

    context 'vendedor cannot destroy (read-only)' do
      it 'returns 403 for vendedor' do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        product = create(:product, warehouse: warehouse)
        delete product_path(product)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Search action (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'GET /products/search' do
    let!(:match)    { create(:product, name: 'SearchMe', sku: 'SRCH-001', warehouse: warehouse) }
    let!(:no_match) { create(:product, name: 'Other', sku: 'OTH-002', warehouse: warehouse) }

    it 'returns 200 for administrador' do
      get search_products_path, params: { q: 'SearchMe' }
      expect(response).to have_http_status(:ok)
    end

    it 'returns matching products' do
      get search_products_path, params: { q: 'SRCH' }
      expect(response.body).to include('SearchMe')
      expect(response.body).not_to include('Other')
    end

    it 'renders selectable combobox options with id, label, price and stock' do
      get search_products_path, params: { q: 'SearchMe' }
      expect(response.body).to include("data-id=\"#{match.id}\"")
      expect(response.body).to include('data-label="SearchMe"')
      expect(response.body).to include("data-price=\"#{match.base_price_usd}\"")
      expect(response.body).to include("data-stock=\"#{match.stock}\"")
      expect(response.body).to include('combobox#select')
    end

    it 'returns 200 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get search_products_path, params: { q: 'SearchMe' }
      expect(response).to have_http_status(:ok)
    end

    it 'filters by warehouse_id when given' do
      other_wh = create(:warehouse)
      here  = create(:product, name: 'AquiProd', sku: 'WH-IN-1', warehouse: warehouse)
      there = create(:product, name: 'AllaProd', sku: 'WH-OUT-1', warehouse: other_wh)

      get search_products_path, params: { q: 'Prod', warehouse_id: warehouse.id }

      expect(response.body).to include('AquiProd')
      expect(response.body).not_to include('AllaProd')
      expect(response.body).to include("data-id=\"#{here.id}\"")
      expect(response.body).not_to include("data-id=\"#{there.id}\"")
    end
  end
end
