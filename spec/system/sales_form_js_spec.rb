require "rails_helper"

# JS system specs for the sale form's client-side behaviors.
#
# Converted from W-3 DEBT skips in sales_spec.rb now that headless Chrome
# is available. These specs exercise Stimulus (sale_form_controller.js) and
# Turbo Frame (client-picker) directly in a real browser.
#
# Driver: headless_chrome (registered in spec/support/capybara.rb, activated
# via js: true metadata tag). Falls back to skip when Chrome is not present.
#
# Authentication: real UI login via system_login_as (see spec/support/
# authentication.rb). The in-process allow_any_instance_of stub used by
# sales_spec.rb does NOT cross into the Capybara/Puma server thread under
# Selenium and MUST NOT be used here.

RSpec.describe "Sale form (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }
  let(:product)   { create(:product, warehouse: warehouse, stock: 100, base_price_usd: 10.00) }
  let(:client)    { create(:client, :ruc_client, full_name: "ACME Corp") }

  before do
    # Materialize the records before login so they exist in the DB.
    warehouse
    product
    client
    system_login_as(admin)
  end

  # ---------------------------------------------------------------------------
  # 1. Add line-item row via Stimulus addLine()
  # ---------------------------------------------------------------------------
  describe "dynamically adds line-item rows via Stimulus controller" do
    it "appends a new tr.line-item row when 'Add Line Item' is clicked" do
      visit new_sale_path

      expect(page).to have_css("tr.line-item", count: 1)

      click_button "Add Line Item"

      expect(page).to have_css("tr.line-item", count: 2)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Live total recompute via Stimulus recompute()
  # ---------------------------------------------------------------------------
  describe "recomputes line totals client-side via Stimulus controller" do
    it "updates the row line total and grand total when quantity and price are entered" do
      visit new_sale_path

      # Fill quantity and unit price in the first (only) row.
      # The inputs carry data-sale-form-target and data-action=input->sale-form#recompute.
      find("input[data-sale-form-target='quantity']").fill_in with: "3"
      find("input[data-sale-form-target='unitPrice']").fill_in with: "5.00"

      # Trigger the input event so Stimulus fires recompute.
      find("input[data-sale-form-target='unitPrice']").send_keys(:tab)

      # Row line total cell must show 3 * 5 = 15.
      expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "USD 15.00")

      # Grand total span must reflect the same amount.
      expect(page).to have_css("[data-sale-form-target='grandTotal']", text: "15.00")
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Turbo Frame client-search swap via Stimulus searchClient()
  # ---------------------------------------------------------------------------
  describe "swaps client-search results inline via Turbo Frame" do
    it "loads matching clients into the client-picker frame when typing in the search field" do
      visit new_sale_path

      # Type into the client search field — triggers input->sale-form#searchClient
      # which updates turbo-frame#client-picker's src attribute, prompting Turbo
      # to fetch /clients/search?q=ACME and replace the frame content.
      fill_in "q", with: "ACME"

      # Capybara auto-waits for the frame content to arrive.
      within("turbo-frame#client-picker") do
        expect(page).to have_content("ACME Corp")
      end
    end
  end
end
