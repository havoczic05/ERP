require "rails_helper"

# System specs for admin-only Company Settings link in the navbar.
# Driver: rack_test — no JS.
RSpec.describe "Navbar", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  # ---------------------------------------------------------------------------
  # Admin nav link
  # ---------------------------------------------------------------------------
  describe "Company Settings nav link" do
    it "§Admin sees settings link" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
      visit root_path
      expect(page).to have_link("Company Settings", href: company_settings_path)
    end

    it "§Vendedor does not see settings link" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      visit root_path
      expect(page).not_to have_link("Company Settings", href: company_settings_path)
    end
  end
end
