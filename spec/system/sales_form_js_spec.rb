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

  # Headless Chrome on WSL2 intermittently drops the click / keystroke events
  # Capybara synthesises before the page settles, so the value never lands or
  # the Stimulus action under test never fires (row not added, total stays
  # USD 0.00, frame searched with an empty query). These helpers set the value
  # and/or dispatch the event the controller listens for directly over CDP,
  # triggering the same handler deterministically while still exercising the
  # real controller in a real browser.

  # Fire a DOM event on a node (e.g. a button click).
  def fire(node, event)
    page.execute_script(
      "arguments[0].dispatchEvent(new Event(arguments[1], { bubbles: true }))",
      node.native, event
    )
  end

  # Set an input's value and fire the event its Stimulus action listens for.
  def set_and_fire(node, value, event)
    page.execute_script(
      "arguments[0].value = arguments[1]; " \
      "arguments[0].dispatchEvent(new Event(arguments[2], { bubbles: true }))",
      node.native, value, event
    )
  end

  # ---------------------------------------------------------------------------
  # 1. Add line-item row via Stimulus addLine()
  # ---------------------------------------------------------------------------
  describe "dynamically adds line-item rows via Stimulus controller" do
    it "appends a new tr.line-item row when 'Add Line Item' is clicked" do
      visit new_sale_path

      expect(page).to have_css("tr.line-item", count: 1)

      fire(find_button("Agregar línea"), "click")

      expect(page).to have_css("tr.line-item", count: 2)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Live total recompute via Stimulus recompute()
  # ---------------------------------------------------------------------------
  describe "recomputes line totals client-side via Stimulus controller" do
    it "updates the row line total and grand total when quantity and price are entered" do
      visit new_sale_path

      # Set quantity and unit price in the first (only) row, then fire the
      # `input` event recompute() is wired to so the controller recomputes from
      # the current DOM values (qty * unit price).
      quantity   = find("input[data-sale-form-target='quantity']")
      unit_price = find("input[data-sale-form-target='unitPrice']")
      set_and_fire(quantity, "3", "input")
      set_and_fire(unit_price, "5.00", "input")

      # Row line total cell must show 3 * 5 = 15.
      expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "USD 15.00")

      # Grand total span must reflect the same amount.
      expect(page).to have_css("[data-sale-form-target='grandTotal']", text: "15.00")
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Client combobox: typing fetches selectable options
  # ---------------------------------------------------------------------------
  describe "client combobox search" do
    it "loads matching clients into the dropdown when typing in the search field" do
      visit new_sale_path

      # Typing fires input->combobox#search, which fetches /clients/search?q=ACME
      # and injects the selectable options.
      set_and_fire(find_field("q"), "ACME", "input")

      expect(page).to have_css("button.picker-option", text: "ACME Corp")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Selecting a client fills client_id and reveals its document + edit link
  # ---------------------------------------------------------------------------
  describe "selecting a client from the dropdown" do
    it "fills the hidden client_id, shows the name, closes, and reveals the document + edit link" do
      visit new_sale_path

      set_and_fire(find_field("q"), "ACME", "input")
      fire(find("button.picker-option", text: "ACME Corp"), "click")

      # Hidden field carries the id; input shows the name; dropdown closes.
      expect(find("input[name='sale[client_id]']", visible: :all).value).to eq(client.id.to_s)
      expect(find_field("q").value).to eq("ACME Corp")
      expect(page).to have_no_css("button.picker-option")

      # The selected client's document + an edit link (new tab) appear.
      within("[data-sale-form-target='clientMeta']") do
        expect(page).to have_text("RUC #{client.document_number}")
        expect(page).to have_css("a[href='#{edit_client_path(client)}'][target='_blank']")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Product combobox: selecting a product autofills its unit price
  # ---------------------------------------------------------------------------
  describe "product combobox autofill" do
    let!(:keyboard) do
      create(:product, warehouse: warehouse, name: "Teclado Mecanico",
             sku: "KEY-001", base_price_usd: 49.90, stock: 25)
    end

    it "fills the row's product_id and unit price, and recomputes the line total" do
      visit new_sale_path

      query = find("input[name='sale[items][][product_query]']")
      set_and_fire(query, "Teclado", "input")
      fire(find("button.picker-option", text: "Teclado Mecanico"), "click")

      expect(find("input[name='sale[items][][product_id]']", visible: :all).value).to eq(keyboard.id.to_s)
      expect(find("input[name='sale[items][][unit_price_usd]']").value).to eq("49.90")

      # qty defaults to 1, so the line total reflects the autofilled price.
      expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "USD 49.90")
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Forma de pago: Contado disables the installment fields, Cuotas enables
  # ---------------------------------------------------------------------------
  describe "payment mode (forma de pago)" do
    def pick_payment(value)
      radio = find("input[name='payment_method'][value='#{value}']", visible: :all)
      page.execute_script(
        "arguments[0].checked = true; " \
        "arguments[0].dispatchEvent(new Event('change', { bubbles: true }))",
        radio.native
      )
    end

    it "disables num_installments/interval for Contado and enables them for Cuotas" do
      visit new_sale_path

      num      = find("input[name='sale[num_installments]']")
      interval = find("select[name='sale[interval_days]']")

      # Default is Contado → both disabled.
      expect(num).to be_disabled
      expect(interval).to be_disabled

      pick_payment("cuotas")
      expect(num).not_to be_disabled
      expect(interval).not_to be_disabled

      pick_payment("contado")
      expect(num).to be_disabled
      expect(interval).to be_disabled
    end
  end
end
