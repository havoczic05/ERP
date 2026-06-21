require "rails_helper"

# System specs for the role-aware sidebar navigation.
# Driver: rack_test — no JS. Role is stubbed at the controller boundary.
RSpec.describe "Sidebar navigation", type: :system do
  before { driven_by(:rack_test) }

  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  def sign_in_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # Sections every authenticated role can reach (authorization already allows them).
  OPERATIONS = {
    "Sales"               => "/sales",
    "Clients"             => "/clients",
    "Products"            => "/products",
    "Accounts Receivable" => "/accounts_receivable",
    "Warehouses"          => "/warehouses"
  }.freeze

  # Admin-only sections.
  ADMINISTRATION = {
    "Dashboard"        => "/dashboard",
    "Users"            => "/users",
    "Company Settings" => "/company_settings"
  }.freeze

  describe "vendedor" do
    before { sign_in_as(vendedor) }

    it "shows every operational section it is authorized to use" do
      visit root_path
      OPERATIONS.each do |label, path|
        expect(page).to have_link(label, href: path)
      end
    end

    it "hides the admin-only sections" do
      visit root_path
      ADMINISTRATION.each_key do |label|
        expect(page).not_to have_link(label)
      end
    end

    it "shows the role and a log out control" do
      visit root_path
      expect(page).to have_content("Vendedor")
      expect(page).to have_button("Log out")
    end
  end

  describe "administrador" do
    before { sign_in_as(admin) }

    it "shows the operational sections" do
      visit root_path
      OPERATIONS.each do |label, path|
        expect(page).to have_link(label, href: path)
      end
    end

    it "shows the admin-only sections" do
      visit root_path
      ADMINISTRATION.each do |label, path|
        expect(page).to have_link(label, href: path)
      end
    end
  end

  describe "active section" do
    before { sign_in_as(vendedor) }

    it "marks the current section with aria-current across its nested pages" do
      visit products_path
      expect(page).to have_css('a.nav-item.is-active[aria-current="page"]', text: "Products")
      # Other sections are not marked active.
      expect(page).to have_no_css('a.nav-item.is-active', text: "Sales")
    end
  end
end
