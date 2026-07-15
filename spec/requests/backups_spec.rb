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
end
