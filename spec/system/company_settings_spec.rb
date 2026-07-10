require "rails_helper"

# System specs for CompanySettings (Slice 3 — admin-only singleton settings form).
# Driver: rack_test — no JS; form submission and file upload via Capybara.
RSpec.describe "CompanySettings", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Show page
  # ---------------------------------------------------------------------------
  describe "show page" do
    it "displays settings fields" do
      create(:company_settings, razon_social: "Empresa Test SAC", ruc: "20123456789",
                                 direccion: "Av. Principal 100", telefono: "012345678")
      visit company_settings_path
      expect(page).to have_content("Empresa Test SAC")
      expect(page).to have_content("20123456789")
      expect(page).to have_content("Av. Principal 100")
      expect(page).to have_content("012345678")
    end

    it "shows a link to edit settings" do
      visit company_settings_path
      expect(page).to have_link("Editar configuración", href: edit_company_settings_path)
    end

    it "shows the import card in the hub sidebar" do
      visit company_settings_path

      within("#hub_import") do
        expect(page).to have_content("Importar datos")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Default-warehouse selector (RF-DW-1, RF-DW-2)
  # ---------------------------------------------------------------------------
  describe "default warehouse selector" do
    let!(:settings) { create(:company_settings) }
    let!(:central)  { create(:warehouse, name: "Almacén Central") }
    let!(:norte)    { create(:warehouse, name: "Almacén Norte") }

    it "offers a select with all warehouses plus a blank option" do
      visit company_settings_path

      within("#hub_default_warehouse") do
        expect(page).to have_select("Almacén predeterminado",
                                     options: [ "Ninguno", "Almacén Central", "Almacén Norte" ])
        expect(page).to have_content("Se preselecciona al crear ventas y productos.")
      end
    end

    it "sets the default warehouse when the admin submits a choice" do
      visit company_settings_path

      within("#hub_default_warehouse") do
        select "Almacén Central", from: "Almacén predeterminado"
        click_button "Guardar"
      end

      expect(CompanySettings.instance.default_warehouse_id).to eq(central.id)
    end

    it "clears the default warehouse when the admin submits the blank option" do
      settings.update!(default_warehouse: central)
      visit company_settings_path

      within("#hub_default_warehouse") do
        select "Ninguno", from: "Almacén predeterminado"
        click_button "Guardar"
      end

      expect(CompanySettings.instance.default_warehouse_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Edit / Update — valid submission
  # ---------------------------------------------------------------------------
  describe "editing company settings" do
    it "admin fills the form and saves, then sees the updated values" do
      visit edit_company_settings_path
      fill_in "Razón social", with: "Nueva Empresa SAC"
      fill_in "RUC", with: "20987654321"
      fill_in "Dirección", with: "Jr. Cusco 456"
      fill_in "Teléfono", with: "999888777"
      find("input[type=submit]").click

      expect(page).to have_current_path(company_settings_path)
      expect(page).to have_content("Configuración actualizada")
      expect(page).to have_content("Nueva Empresa SAC")
      expect(page).to have_content("20987654321")
    end

    it "shows validation errors when RUC is invalid" do
      visit edit_company_settings_path
      fill_in "Razón social", with: "Empresa"
      fill_in "RUC", with: "1234"
      find("input[type=submit]").click

      expect(page).to have_content("debe tener exactamente 11 dígitos numéricos")
    end
  end

  # ---------------------------------------------------------------------------
  # Subtitulo + bank accounts (static parts — the add/remove row UI is JS-only,
  # so rack_test only exercises the rendered fields and persistence via submit).
  # ---------------------------------------------------------------------------
  describe "subtitulo and bank accounts" do
    it "shows the subtitulo field and saves it" do
      visit edit_company_settings_path
      fill_in "Razón social", with: "Empresa SAC"
      fill_in "RUC", with: "20123456789"
      fill_in "Subtítulo", with: "Importadora y Distribuidora"
      find("input[type=submit]").click

      expect(page).to have_content("Importadora y Distribuidora")
    end

    it "renders existing bank accounts in the edit form" do
      settings = create(:company_settings)
      create(:bank_account, company_settings: settings, bank: "BCP", currency_label: "Dólares")
      visit edit_company_settings_path

      expect(page).to have_content("Cuentas bancarias")
      expect(page).to have_field("Banco", with: "BCP")
    end

    it "shows bank accounts on the details page" do
      settings = create(:company_settings)
      create(:bank_account, company_settings: settings, bank: "BCP",
                            account_number: "193-9852295-1-39")
      visit company_settings_path

      expect(page).to have_content("BCP")
      expect(page).to have_content("193-9852295-1-39")
    end
  end

  # ---------------------------------------------------------------------------
  # Logo upload
  # ---------------------------------------------------------------------------
  describe "logo attachment" do
    it "admin can attach a logo file" do
      visit edit_company_settings_path
      fill_in "Razón social", with: "Logo Corp"
      fill_in "RUC", with: "20123456789"
      attach_file "Logo", Rails.root.join("spec/fixtures/files/logo.png")
      find("input[type=submit]").click

      expect(page).to have_current_path(company_settings_path)
      expect(CompanySettings.first.logo.attached?).to be true
    end

    it "constrains the logo preview to a fixed-size tile" do
      visit edit_company_settings_path
      fill_in "Razón social", with: "Logo Corp"
      fill_in "RUC", with: "20123456789"
      attach_file "Logo", Rails.root.join("spec/fixtures/files/logo.png")
      find("input[type=submit]").click

      expect(page).to have_css("img.company-logo")
    end
  end
end
