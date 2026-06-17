require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  before { driven_by(:rack_test) }

  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client) }

  before do
    login_as(admin)
    sale = create(:sale, :venta, client: client, warehouse: warehouse,
                  subtotal_usd: 100.00, total_usd: 100.00)
    product = create(:product, name: "Top Seller", stock: 5, warehouse: warehouse)
    create(:sale_item, sale: sale, product: product, quantity: 7,
           unit_price_usd: 10.00, line_total_usd: 70.00)
    create(:installment, sale: sale, installment_number: 1, status: "pendiente",
           amount_usd: 100.00, balance_usd: 100.00, due_date: Date.current - 2)
  end

  it "shows the analytics sections" do
    visit dashboard_path

    expect(page).to have_content(/ventas|sales/i)
    expect(page).to have_content("Top Seller")  # top product ranking
  end

  it "renders the temporal charts as inline SVG" do
    visit dashboard_path
    expect(page).to have_css("svg", minimum: 1)
  end

  it "does not expose any create/new shortcuts (PRD §3.6 is read-only)" do
    visit dashboard_path
    expect(page).not_to have_link(href: new_sale_path)
    expect(page).not_to have_selector("a", text: /nuevo|new/i)
  end
end
