require "rails_helper"

# Request specs for ImportsController (PR3b — admin-only import UI).
# Covers: new_products / create_products, new_clients / create_clients,
#         product_template / client_template — for admin, vendedor, and unauthenticated.
RSpec.describe "Imports", type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Authorization — products
  # ---------------------------------------------------------------------------
  describe "GET /config/importar/productos" do
    it "§Admin GET new_products returns 200" do
      get import_new_products_path
      expect(response).to have_http_status(:ok)
    end

    it "§Vendedor GET new_products is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get import_new_products_path
      expect(response).to have_http_status(:forbidden)
    end

    it "§Unauthenticated GET new_products redirects" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      get import_new_products_path
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization — clients
  # ---------------------------------------------------------------------------
  describe "GET /config/importar/clientes" do
    it "§Admin GET new_clients returns 200" do
      get import_new_clients_path
      expect(response).to have_http_status(:ok)
    end

    it "§Vendedor GET new_clients is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get import_new_clients_path
      expect(response).to have_http_status(:forbidden)
    end

    it "§Unauthenticated GET new_clients redirects" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      get import_new_clients_path
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST create_products — valid upload
  # ---------------------------------------------------------------------------
  describe "POST /config/importar/productos" do
    let!(:warehouse) { create(:warehouse, name: "Almacén Central") }

    context "with a valid CSV" do
      let(:file) { fixture_file_upload("products_valid.csv", "text/csv") }
      # Only Almacén Central is seeded — rows 2 and 3 resolve to Almacén Norte / Sur
      # (not seeded) and become row errors, so exactly 1 product is created.
      let!(:norte) { create(:warehouse, name: "Almacén Norte") }
      let!(:sur)   { create(:warehouse, name: "Almacén Sur") }

      it "§Admin POST create_products returns 200 (turbo_stream) and creates products" do
        expect {
          post import_create_products_path, params: { file: file },
               headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        }.to change(Product, :count).by(3)
        expect(response).to have_http_status(:ok)
      end

      it "§Response body contains the report partial container" do
        post import_create_products_path, params: { file: file },
             headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response.body).to include("import_results")
      end
    end

    context "with an invalid file type" do
      let(:file) { fixture_file_upload("logo.png", "image/png") }

      it "§Admin POST create_products with bad format returns 422 with Spanish error" do
        post import_create_products_path, params: { file: file }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("CSV")
      end
    end

    context "without a file" do
      it "§Admin POST create_products without a file returns 422 with Spanish error" do
        post import_create_products_path, params: {}
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "vendedor is forbidden" do
      let(:file) { fixture_file_upload("products_valid.csv", "text/csv") }

      it "§Vendedor POST create_products is forbidden" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        post import_create_products_path, params: { file: file }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST create_clients — valid upload
  # ---------------------------------------------------------------------------
  describe "POST /config/importar/clientes" do
    context "with a valid CSV" do
      let(:file) { fixture_file_upload("clients_valid.csv", "text/csv") }

      it "§Admin POST create_clients returns 200 and creates clients" do
        expect {
          post import_create_clients_path, params: { file: file },
               headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        }.to change(Client, :count).by(2)
        expect(response).to have_http_status(:ok)
      end
    end

    context "vendedor is forbidden" do
      let(:file) { fixture_file_upload("clients_valid.csv", "text/csv") }

      it "§Vendedor POST create_clients is forbidden" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        post import_create_clients_path, params: { file: file }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Template downloads
  # ---------------------------------------------------------------------------
  describe "GET /config/importar/productos/plantilla" do
    it "§Admin GET product_template returns CSV with correct headers" do
      get import_product_template_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("SKU")
      expect(response.body).to include("Nombre")
      expect(response.body).to include("Almacén")
      expect(response.body).to include("Precio base USD")
    end

    it "§Vendedor GET product_template is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get import_product_template_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /config/importar/clientes/plantilla" do
    it "§Admin GET client_template returns CSV with correct headers" do
      get import_client_template_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("Nombre completo")
      expect(response.body).to include("Número de documento")
      expect(response.body).to include("Departamento")
    end

    it "§Vendedor GET client_template is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get import_client_template_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
