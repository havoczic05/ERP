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

    it "§renders Moneda as a select with Soles/Dólares options" do
      get edit_company_settings_path
      expect(response.body).to match(/<select[^>]*currency_label/)
      expect(response.body).to include(">Soles</option>")
      expect(response.body).to include(">Dólares</option>")
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

    it "§PATCH saves the subtitulo" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          subtitulo: "Importadora y Distribuidora" } }
      expect(CompanySettings.first.subtitulo).to eq("Importadora y Distribuidora")
    end

    it "§PATCH creates bank accounts via nested attributes" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          bank_accounts_attributes: {
                                            "0" => { bank: "BCP", currency_label: "Dólares",
                                                     account_number: "193-9852295-1-39",
                                                     interbank_number: "002-193-009852295139-15",
                                                     position: "0" }
                                          } } }
      expect(CompanySettings.first.bank_accounts.count).to eq(1)
      expect(CompanySettings.first.bank_accounts.first.bank).to eq("BCP")
    end

    # Strong Parameters only permits nested-attributes rows whose key is an
    # integer (/\A-?\d+\z/). The nested-form JS must emit integer indices for new
    # rows (a timestamp), NOT "new_N", or the rows get silently dropped and the
    # account is never created even though the update "succeeds".
    it "§turbo update creates and re-renders a new account added with an integer index" do
      patch company_settings_path,
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          bank_accounts_attributes: {
                                            "1720000000000" => { bank: "BCP", currency_label: "Soles",
                                                                 account_number: "193-9898120-0-08", position: "0" }
                                          } } }
      expect(CompanySettings.first.bank_accounts.count).to eq(1)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Cuentas bancarias")
      expect(response.body).to include("BCP")
      expect(response.body).to include("193-9898120-0-08")
    end

    it "§Strong Parameters drops a non-integer nested key (guards the JS contract)" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          bank_accounts_attributes: {
                                            "new_1" => { bank: "BCP", account_number: "193-X", position: "0" }
                                          } } }
      # Documents Rails behavior: the non-integer "new_1" row never reaches the
      # model, so nothing is created. The real fix lives in the nested-form JS.
      expect(BankAccount.count).to eq(0)
    end

    it "§PATCH does not silently drop a bank account missing only the bank name" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          bank_accounts_attributes: {
                                            "0" => { bank: "", currency_label: "Soles",
                                                     account_number: "193-9898120-0-08", position: "0" }
                                          } } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("no puede estar en blanco")
      expect(BankAccount.count).to eq(0)
    end

    it "§PATCH ignores a completely blank bank account row" do
      patch company_settings_path,
            params: { company_settings: { razon_social: "Mi Empresa", ruc: "20987654321",
                                          bank_accounts_attributes: {
                                            "0" => { bank: "", currency_label: "", account_number: "",
                                                     interbank_number: "", position: "0" }
                                          } } }
      expect(response).to have_http_status(:found)
      expect(CompanySettings.first.bank_accounts.count).to eq(0)
    end

    it "§PATCH removes a bank account via _destroy" do
      settings = create(:company_settings)
      account  = create(:bank_account, company_settings: settings)
      patch company_settings_path,
            params: { company_settings: { razon_social: settings.razon_social, ruc: settings.ruc,
                                          bank_accounts_attributes: {
                                            "0" => { id: account.id, _destroy: "1" }
                                          } } }
      expect(CompanySettings.first.bank_accounts.count).to eq(0)
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

    it "§PATCH with a non-existent default_warehouse_id fails gracefully (no 500)" do
      settings = create(:company_settings)
      expect {
        patch company_settings_path,
              params: { company_settings: { razon_social: settings.razon_social, ruc: settings.ruc,
                                            default_warehouse_id: 999_999 } }
      }.not_to raise_error
      expect(response).to have_http_status(:unprocessable_content)
      expect(settings.reload.default_warehouse_id).to be_nil
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
