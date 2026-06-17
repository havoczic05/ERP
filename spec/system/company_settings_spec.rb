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
      expect(page).to have_link("Edit Settings", href: edit_company_settings_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Edit / Update — valid submission
  # ---------------------------------------------------------------------------
  describe "editing company settings" do
    it "admin fills the form and saves, then sees the updated values" do
      visit edit_company_settings_path
      fill_in "Razon social", with: "Nueva Empresa SAC"
      fill_in "Ruc", with: "20987654321"
      fill_in "Direccion", with: "Jr. Cusco 456"
      fill_in "Telefono", with: "999888777"
      find("input[type=submit]").click

      expect(page).to have_current_path(company_settings_path)
      expect(page).to have_content("Settings updated")
      expect(page).to have_content("Nueva Empresa SAC")
      expect(page).to have_content("20987654321")
    end

    it "shows validation errors when RUC is invalid" do
      visit edit_company_settings_path
      fill_in "Razon social", with: "Empresa"
      fill_in "Ruc", with: "1234"
      find("input[type=submit]").click

      expect(page).to have_content("must be exactly 11 numeric digits")
    end
  end

  # ---------------------------------------------------------------------------
  # Logo upload
  # ---------------------------------------------------------------------------
  describe "logo attachment" do
    it "admin can attach a logo file" do
      visit edit_company_settings_path
      fill_in "Razon social", with: "Logo Corp"
      fill_in "Ruc", with: "20123456789"
      attach_file "Logo", Rails.root.join("spec/fixtures/files/logo.png")
      find("input[type=submit]").click

      expect(page).to have_current_path(company_settings_path)
      expect(CompanySettings.first.logo.attached?).to be true
    end
  end
end
