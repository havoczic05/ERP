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

    it "reserves empty slots for the upcoming default-warehouse and import features" do
      visit company_settings_path

      expect(find("#hub_default_warehouse", visible: :all).text).to eq("")
      expect(find("#hub_import", visible: :all).text).to eq("")
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
