require "rails_helper"

# System specs for ImportsController (PR3b — import UI).
# Driver: rack_test (no JS needed for upload flow).
# Covers: hub import card rendering, upload → per-row report + toast summary.
RSpec.describe "Imports", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Hub import card (RF-IMP-1 entry point from hub)
  # ---------------------------------------------------------------------------
  describe "hub import card" do
    before { create(:company_settings) }

    it "renders the Importar datos card in the hub sidebar" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_content("Importar datos")
      end
    end

    it "shows Productos and Clientes sections in the hub import card" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_content("Productos")
        expect(page).to have_content("Clientes")
      end
    end

    it "shows helper text about accepted formats" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_content("CSV")
        expect(page).to have_content("XLSX")
        expect(page).to have_content("500")
      end
    end

    it "has a link to import products" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_link("Importar archivo", href: import_new_products_path)
      end
    end

    it "has a link to import clients" do
      visit company_settings_path
      within("#hub_import") do
        # There are two "Importar archivo" links; the clientes one links to new_clients
        expect(page).to have_link(href: import_new_clients_path)
      end
    end

    it "has a product template download link" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_link("Plantilla", href: import_product_template_path)
      end
    end

    it "has a client template download link" do
      visit company_settings_path
      within("#hub_import") do
        expect(page).to have_link(href: import_client_template_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Products import upload flow
  # ---------------------------------------------------------------------------
  describe "products upload flow" do
    let!(:warehouse) { create(:warehouse, name: "Almacén Central") }

    it "shows the upload form on new_products" do
      visit import_new_products_path
      expect(page).to have_content("Importar productos")
      expect(page).to have_css("input[type=file]")
    end

    it "shows per-row report and toast after valid CSV upload" do
      visit import_new_products_path
      attach_file "Archivo", Rails.root.join("spec/fixtures/files/products_valid.csv")
      click_button "Importar"

      expect(page).to have_content("creados")
    end

    it "shows a Spanish error for a non-CSV file" do
      visit import_new_products_path
      attach_file "Archivo", Rails.root.join("spec/fixtures/files/logo.png")
      click_button "Importar"

      expect(page).to have_content("CSV")
    end
  end

  # ---------------------------------------------------------------------------
  # Clients import upload flow
  # ---------------------------------------------------------------------------
  describe "clients upload flow" do
    it "shows the upload form on new_clients" do
      visit import_new_clients_path
      expect(page).to have_content("Importar clientes")
      expect(page).to have_css("input[type=file]")
    end

    it "shows per-row report after valid CSV upload" do
      visit import_new_clients_path
      attach_file "Archivo", Rails.root.join("spec/fixtures/files/clients_valid.csv")
      click_button "Importar"

      expect(page).to have_content("creados")
    end
  end
end
