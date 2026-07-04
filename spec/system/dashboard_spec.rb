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

  it "offers a time-range toggle for the temporal charts" do
    visit dashboard_path
    expect(page).to have_link("Mes", href: dashboard_path(range: "month"))
    expect(page).to have_link("30 días", href: dashboard_path(range: "30d"))
    expect(page).to have_link("7 días", href: dashboard_path(range: "7d"))
  end

  it "marks the selected range as active" do
    visit dashboard_path(range: "7d")
    expect(page).to have_css("a.range-opt--active", text: "7 días")
  end

  it "wraps the temporal charts in a turbo-frame so toggling updates them in place" do
    visit dashboard_path
    expect(page).to have_css("turbo-frame#dashboard-charts .chart-range")
    expect(page).to have_css("turbo-frame#dashboard-charts .chart", minimum: 2)
  end

  it "does not expose any create/new shortcuts (PRD §3.6 is read-only)" do
    visit dashboard_path
    expect(page).not_to have_link(href: new_sale_path)
    expect(page).not_to have_selector("a", text: /nuevo|new/i)
  end

  it "deep-links each KPI to its matching filtered list" do
    visit dashboard_path

    expect(page).to have_link(
      href: sales_path(document_type: "venta", status: "confirmada", date_range: "month")
    )
    expect(page).to have_link(
      href: sales_path(document_type: "venta", status: "confirmada", date_range: "today")
    )
    expect(page).to have_link(href: accounts_receivable_path)
    expect(page).to have_link(href: accounts_receivable_path(status: "vencida"))
  end

  it "links ranking and low-stock rows to the product detail" do
    visit dashboard_path
    product = Product.find_by!(name: "Top Seller")
    expect(page).to have_link(href: product_path(product))
  end

  it "links panel headers to the full products list" do
    visit dashboard_path
    expect(page).to have_link("Ver todos", href: products_path)
  end

  it "shows the cobrado del mes KPI and drops the Por cobrar / Ticket promedio tiles" do
    visit dashboard_path
    expect(page).to have_content("Cobrado del mes")
    expect(page).not_to have_content("Por cobrar")
    expect(page).not_to have_content("Ticket promedio")
  end

  it "renders a trend badge when there is a previous-month baseline" do
    create(:sale, :venta, client: client, warehouse: warehouse,
           subtotal_usd: 50.00, total_usd: 50.00, created_at: 1.month.ago)
    visit dashboard_path
    expect(page).to have_css(".trend")
  end

  it "lists installments coming due within the next 7 days" do
    soon_client = create(:client, :ruc_client, full_name: "Cliente Próximo")
    soon_sale = create(:sale, :venta, client: soon_client, warehouse: warehouse,
                       subtotal_usd: 100.00, total_usd: 100.00)
    create(:installment, sale: soon_sale, installment_number: 1, status: "pendiente",
           amount_usd: 100.00, balance_usd: 100.00, due_date: Date.current + 3)

    visit dashboard_path
    expect(page).to have_content("Vencimientos de la Semana")
    expect(page).to have_content("Cliente Próximo")
  end

  it "links each upcoming installment to accounts receivable filtered by its sale correlative" do
    soon_sale = create(:sale, :venta, client: client, warehouse: warehouse,
                       subtotal_usd: 100.00, total_usd: 100.00)
    create(:installment, sale: soon_sale, installment_number: 1, status: "pendiente",
           amount_usd: 100.00, balance_usd: 100.00, due_date: Date.current + 3)

    visit dashboard_path
    expect(page).to have_link(href: accounts_receivable_path(q: soon_sale.correlative))
  end
end
