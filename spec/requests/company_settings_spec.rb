require "rails_helper"

# Request specs for CompanySettingsController (Slice 3 — admin-only singleton settings).
# Covers: show/edit/update for admin, 403 for vendedor, redirect for unauthenticated, logo upload.
RSpec.describe "CompanySettings", type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # GET show
  # ---------------------------------------------------------------------------
  describe "GET /company_settings" do
    it "§Admin GET show returns 200" do
      get company_settings_path
      expect(response).to have_http_status(:ok)
    end

    it "§Vendedor GET show is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get company_settings_path
      expect(response).to have_http_status(:forbidden)
    end

    it "§Unauthenticated GET show redirects" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      get company_settings_path
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # GET edit
  # ---------------------------------------------------------------------------
  describe "GET /company_settings/edit" do
    it "§Admin GET edit returns 200" do
      get edit_company_settings_path
      expect(response).to have_http_status(:ok)
    end

    it "§Vendedor GET edit is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get edit_company_settings_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH update
  # ---------------------------------------------------------------------------
  describe "PATCH /company_settings" do
    let(:valid_params) do
      { company_settings: { razon_social: "Mi Empresa S.A.", ruc: "20987654321",
                             direccion: "Av. Lima 123", telefono: "987654321" } }
    end

    it "§Valid PATCH update persists and redirects" do
      patch company_settings_path, params: valid_params
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(company_settings_path)
      follow_redirect!
      expect(response.body).to include("Configuración actualizada")
      expect(CompanySettings.first.razon_social).to eq("Mi Empresa S.A.")
    end

    it "§Invalid PATCH (RUC 10 digits) does not persist" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "2012345678" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(CompanySettings.count).to eq(0)
    end

    it "§PATCH can attach logo" do
      file = fixture_file_upload("logo.png", "image/png")
      patch company_settings_path,
            params: { company_settings: { razon_social: "Logo Corp", ruc: "20123456789",
                                          logo: file } }
      expect(response).to have_http_status(:found)
      expect(CompanySettings.first.logo.attached?).to be true
    end

    it "§Vendedor PATCH is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      patch company_settings_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    it "§Unauthenticated PATCH redirects" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      patch company_settings_path, params: valid_params
      expect(response).to have_http_status(:redirect)
    end
  end
end
