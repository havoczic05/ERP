require "rails_helper"

# System specs for BackupsController — admin-only pg_dump download.
# Driver: rack_test (no JS needed for the download flow).
RSpec.describe "Backups", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Hub backup card (sidebar entry point on Company Settings)
  # ---------------------------------------------------------------------------
  describe "hub backup card" do
    before { create(:company_settings) }

    it "renders the Respaldo card in the hub sidebar" do
      visit company_settings_path
      within("#hub_backup") do
        expect(page).to have_content("Respaldo")
      end
    end

    it "has a link to the backup page from the hub card" do
      visit company_settings_path
      within("#hub_backup") do
        expect(page).to have_link("Crear respaldo", href: backup_new_path)
      end
    end

    it "shows description text in the hub card" do
      visit company_settings_path
      within("#hub_backup") do
        expect(page).to have_content("base de datos")
        expect(page).to have_content("SQL")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Backup page (new)
  # ---------------------------------------------------------------------------
  describe "backup page" do
    it "renders the backup page with Spanish heading" do
      visit backup_new_path
      expect(page).to have_content("Respaldo de base de datos")
    end

    it "shows the settings navigation on the backup page" do
      visit backup_new_path
      within(".settings-nav") do
        expect(page).to have_content("Respaldo")
      end
    end

    it "shows the Create button" do
      visit backup_new_path
      expect(page).to have_button("Crear respaldo")
    end

    it "shows admin-only hint" do
      visit backup_new_path
      expect(page).to have_content("administradores")
    end
  end

  # ---------------------------------------------------------------------------
  # Backup download flow
  # ---------------------------------------------------------------------------
  describe "backup download" do
    before do
      allow(BackupService).to receive(:call).and_return(
        Result.success("-- PostgreSQL dump\nCREATE TABLE public.users ...\n")
      )
    end

    it "downloads a .sql file when clicking Crear respaldo" do
      visit backup_new_path
      click_button "Crear respaldo"

      expect(response_headers["Content-Type"]).to include("application/sql")
      expect(response_headers["Content-Disposition"]).to include("attachment")
      expect(response_headers["Content-Disposition"]).to include(".sql")
    end
  end
end
