require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  describe "GET /dashboard" do
    it "returns 200 for an administrador" do
      login_as(admin)
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "is forbidden for a vendedor" do
      login_as(vendedor)
      get dashboard_path
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects to login when unauthenticated" do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
  end
end
