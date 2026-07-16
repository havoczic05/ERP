require "rails_helper"

# Request specs for BackupsController — admin-only PostgreSQL backup page.
# Covers: GET /config/respaldo (new), POST /config/respaldo (create)
#         for admin, vendedor, and unauthenticated users.
RSpec.describe "Backups", type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Authorization — GET new
  # ---------------------------------------------------------------------------
  describe "GET /config/respaldo" do
    it "§Admin GET new returns 200" do
      get backup_new_path
      expect(response).to have_http_status(:ok)
    end

    it "§Vendedor GET new is forbidden" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get backup_new_path
      expect(response).to have_http_status(:forbidden)
    end

    it "§Unauthenticated GET new redirects" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      get backup_new_path
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization — POST create
  # ---------------------------------------------------------------------------
  describe "POST /config/respaldo" do
    context "when BackupService succeeds" do
      before do
        allow(BackupService).to receive(:call).and_return(
          Result.success("-- PostgreSQL dump\n")
        )
        allow(BackupService).to receive(:dump_to_file).and_return(
          Result.success("/tmp/erp-2026-07-15-0300.sql")
        )
      end

      it "§Admin POST create returns 200 with SQL content-type" do
        post backup_create_path
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/sql")
      end

      it "§Admin POST create sets Content-Disposition header with .sql filename" do
        post backup_create_path
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".sql")
      end

      it "§Admin POST create returns the dump data in the response body" do
        post backup_create_path
        expect(response.body).to include("PostgreSQL dump")
      end
    end

    context "when BackupService fails" do
      before do
        allow(BackupService).to receive(:call).and_return(
          Result.failure(nil, [ "pg_dump no está disponible en el sistema" ])
        )
      end

      it "§Admin POST create returns 422 with flash alert" do
        post backup_create_path
        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to be_present
      end
    end

    context "vendedor is forbidden" do
      it "§Vendedor POST create is forbidden" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
        post backup_create_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "unauthenticated user is redirected" do
      it "§Unauthenticated POST create redirects" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
        post backup_create_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET download — REQ-BKP-102
  # ---------------------------------------------------------------------------
  describe "GET /config/respaldo/download" do
    let(:backup_dir) { Rails.root.join("db", "backups") }
    let(:filename) { "erp-2026-07-15-0300.sql" }
    let(:filepath) { backup_dir.join(filename) }

    before do
      FileUtils.mkdir_p(backup_dir)
      File.write(filepath, "-- test dump\n")
    end

    after do
      FileUtils.rm_rf(backup_dir)
    end

    # SCEN-102-a: valid file download
    it "streams the file with SQL content-type and attachment disposition" do
      get backup_download_path(filename: filename)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/sql")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(filename)
    end

    # SCEN-102-b: path traversal rejection
    it "rejects path traversal filenames with 400" do
      get backup_download_path(filename: "../../../etc/passwd")
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects names not matching the expected pattern" do
      get backup_download_path(filename: "evil.exe")
      expect(response).to have_http_status(:bad_request)
    end

    # SCEN-102-c: nonexistent file
    it "returns 404 for nonexistent file with valid pattern" do
      get backup_download_path(filename: "erp-2099-01-01-0000.sql")
      expect(response).to have_http_status(:not_found)
    end

    # SCEN-102-d: unauthorized
    it "returns 403 for vendedor" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get backup_download_path(filename: filename)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects unauthenticated user" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      get backup_download_path(filename: filename)
      expect(response).to have_http_status(:redirect)
    end
  end
end
