require "rails_helper"

# JS system spec for the cotizacion→venta convert form (two-step editable flow).
#
# Exercises the preloaded form: the cotizacion's items are hydrated into the
# line-item rows with their totals, and submitting builds a linked venta.
#
# Driver: headless_chrome via js: true (see spec/support/capybara.rb).
RSpec.describe "Convert cotizacion to venta (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }
  let(:product)   { create(:product, warehouse: warehouse, name: "Heladera", sku: "HEL-1", stock: 100, base_price_usd: 200.00) }
  let(:client)    { create(:client, :ruc_client, full_name: "ACME Corp") }

  let(:cotizacion) do
    sale = create(:sale, client: client, warehouse: warehouse,
                  document_type: "cotizacion", status: "confirmada",
                  subtotal_usd: 400.00, total_usd: 400.00)
    create(:sale_item, sale: sale, product: product, quantity: 2,
           unit_price_usd: 200.00, line_total_usd: 400.00)
    sale
  end

  before do
    cotizacion
    system_login_as(admin)
  end

  it "preloads the cotizacion items with computed totals" do
    visit convert_sale_path(cotizacion)

    # The single item row is hydrated: product name, quantity, unit price.
    expect(page).to have_css("tr.line-item", count: 1)
    expect(find("input[name='sale[items][][product_query]']").value).to include("Heladera")
    expect(find("input[data-sale-form-target='quantity']").value).to eq("2")
    expect(find("input[data-sale-form-target='unitPrice']").value).to eq("200.00")

    # recomputeAll() on connect renders the line + grand totals immediately.
    expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "400.00")
    expect(page).to have_css("[data-sale-form-target='grandTotal']", text: "400.00")

    # The selected client strip is revealed with the preloaded client.
    within("[data-sale-form-target='clientStrip']") do
      expect(page).to have_text("ACME Corp")
    end
  end

  it "creates a linked venta on submit" do
    visit convert_sale_path(cotizacion)

    click_button "Convertir a venta"

    # Wait for the redirect+flash (Capybara waits) before touching the DB, so the
    # server thread has committed the new venta by the time we query for it.
    expect(page).to have_content("Cotización convertida a venta correctamente")

    venta = Sale.find_by(source_cotizacion_id: cotizacion.id)
    expect(venta).to be_present
    expect(venta.document_type).to eq("venta")
    expect(page).to have_current_path(sale_path(venta))
  end
end
